using System.Text.Json;
using Npgsql;

namespace Example;

public sealed class EventingConsumer : IDisposable
{
    public event MessageHandler OnMessageReceived;
    private readonly NpgsqlDataSource dataSource;
    private NpgsqlConnection listeningConnection;
    private volatile string channelId;

    public EventingConsumer(string connectionString)
    {
        this.dataSource = NpgsqlDataSource.Create(connectionString);
    }

    public void OpenChannel(string queueName)
    {
        if (channelId is not null) 
        {
            return;
        }

        listeningConnection = CreateListeningConnection(dataSource);
        using var transaction = listeningConnection.BeginTransaction();

        listeningConnection.Notification += (sender, args) =>
        {
            var message = JsonSerializer.Deserialize<Message>(args.Payload);
            if (message is null) return;
            Task.Run(() => OnMessageReceived?.Invoke(message, () => Ack(message.DeliveryId)));
        };

        using var openChannelCommand = new NpgsqlCommand("SELECT mq.open_channel($1)", listeningConnection, transaction)
        {
            Parameters = { new() { Value = queueName } }
        };
        channelId = (string)openChannelCommand.ExecuteScalar();
        transaction.Commit();
    }

    public void Wait()
    {
        listeningConnection?.Wait();
    }

    public void Ack(long deliveryId)
    {
        using var cmd = dataSource.CreateCommand($"SELECT mq.ack({deliveryId}, true)");
        cmd.ExecuteNonQuery();
    }

    public void CloseChannel()
    {
        if (channelId is null)
        {
            return;
        }

        Console.WriteLine($"Closing channel {channelId}");
        using var unregisterChannel = dataSource.CreateCommand($"SELECT mq.close_channel({channelId});");
        unregisterChannel.ExecuteNonQuery();
        channelId = null;
        listeningConnection?.Dispose();
        listeningConnection = null;
    }

    private NpgsqlConnection CreateListeningConnection(NpgsqlDataSource dataSource)
    {
        var listeningConnection = dataSource.OpenConnection();
        return listeningConnection;
    }

    public delegate void MessageHandler(Message m, Action ack);

    public void Dispose()
    {
        dataSource?.Dispose();
        listeningConnection?.Dispose();
    }
}