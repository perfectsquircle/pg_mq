// See https://aka.ms/new-console-template for more information
using System.Text.Json.Nodes;
using Npgsql;
var connectionString = "Host=localhost;Username=cfurano;Password=;Database=pg_mq_poc;";
await using var dataSource = NpgsqlDataSource.Create(connectionString);
using var listeningConnection = dataSource.CreateConnection();
listeningConnection.Open();

listeningConnection.Notification += (sender, args) =>
{
    Task.Run(() =>
    {
        try
        {
            Console.WriteLine(args.Payload);
            var deliveredMessage = JsonNode.Parse(args.Payload);
            var deliveryId = deliveredMessage["delivery_id"];
            Console.WriteLine($"Delivery ID: {deliveryId}");
            Thread.Sleep(250);
            using var cmd = dataSource.CreateCommand($"SELECT mq.ack({deliveryId}, true)");
            cmd.ExecuteNonQuery();
            Console.WriteLine("Message acked.");
        }
        catch (Exception e)
        {
            Console.Error.WriteLine(e.Message);
        }
    });
};

using var transaction = listeningConnection.BeginTransaction();
using var registerChannel = new NpgsqlCommand("SELECT mq.register_channel()", listeningConnection, transaction);
var channelId = registerChannel.ExecuteScalar();
transaction.Commit();

var keepRunning = true;
Console.CancelKeyPress += delegate (object? sender, ConsoleCancelEventArgs e)
{
    e.Cancel = true;
    keepRunning = false;
};

try
{
    while (keepRunning)
    {
        listeningConnection.Wait(); // Thread will block here
    }
}
finally
{
    Console.WriteLine($"Closing channel {channelId}");
    using var unregisterChannel = dataSource.CreateCommand($"SELECT mq.unregister_channel({channelId});");
    unregisterChannel.ExecuteNonQuery();
}
