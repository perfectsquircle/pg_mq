using System.Data;
using System.Text.Json;
using Npgsql;

namespace Example;

public sealed class EventingConsumer : IDisposable
{
    public event MessageHandler OnMessageReceived;
    private readonly NpgsqlDataSource dataSource;
    private NpgsqlConnection listeningConnection;
    public EventingConsumer(string connectionString)
    {
        this.dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public void OpenChannel(string queueName)
    {
        if (listeningConnection is not null)
        {
            return;
        }

        listeningConnection = dataSource.OpenConnection();
        using var transaction = listeningConnection.BeginTransaction();

        listeningConnection.Notification += (sender, args) =>
        {
            if (string.IsNullOrEmpty(args.Payload)) return;
            Task.Run(() => {
                var message = JsonSerializer.Deserialize<Message>(args.Payload);
                if (message is null) return;
                OnMessageReceived?.Invoke(message, () => Ack(message.DeliveryId));
            });
        };

        using var openChannelCommand = new NpgsqlCommand("mq.open_channel", listeningConnection, transaction)
        {
            CommandType = CommandType.StoredProcedure,
            Parameters = { new() { Value = queueName } }
        };
        openChannelCommand.ExecuteNonQuery();
        transaction.Commit();
    }

    public void Wait()
    {
        listeningConnection?.Wait();
    }

    public void Ack(long deliveryId)
    {
        using var cmd = dataSource.CreateCommand("mq.ack");
        cmd.CommandType = CommandType.StoredProcedure;
        cmd.Parameters.Add(new NpgsqlParameter { Value = deliveryId });
        cmd.ExecuteNonQuery();
    }

    public void CloseChannel()
    {
        Console.WriteLine($"Closing channel");
        using var closeChannelCommand = new NpgsqlCommand("mq.close_channel", listeningConnection)
        {
            CommandType = CommandType.StoredProcedure,
        };
        closeChannelCommand.ExecuteNonQuery();
        listeningConnection?.Dispose();
        listeningConnection = null;
    }

    public delegate void MessageHandler(Message m, Action ack);

    public void Dispose()
    {
        dataSource?.Dispose();
        listeningConnection?.Dispose();
    }
}