using Example;

var connectionString = "Host=localhost;Username=cfurano;Password=cfurano;Database=pg_mq_poc;";
using var consumer = new EventingConsumer(connectionString);
consumer.OnMessageReceived += HandleMessage;
consumer.OpenChannel("Default Queue");

var keepRunning = true;
Console.CancelKeyPress += (sender, args) =>
{
    args.Cancel = true;
    keepRunning = false;
};

try
{
    while (keepRunning)
    {
        consumer.Wait(); // Thread will block here
    }
}
finally
{
    consumer.CloseChannel();
}

static void HandleMessage(Message message, Action ack)
{
    try
    {
        Console.WriteLine(message.Payload);
        var deliveryId = message.DeliveryId;
        Console.WriteLine($"Delivery ID: {deliveryId}");
        Thread.Sleep(250);
        ack();
        Console.WriteLine("Message acked.");
    }
    catch (Exception e)
    {
        Console.Error.WriteLine(e.Message);
    }
}