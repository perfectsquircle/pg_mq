using Example;

var connectionString = "Host=localhost;Username=cfurano;Password=cfurano;Database=pg_mq_poc;";
using var consumer = new EventingConsumer(connectionString);
consumer.OnMessageReceived += HandleMessage;
var queueName = "Default Queue";
consumer.OpenChannel(queueName);

var keepRunning = true;
Console.CancelKeyPress += (sender, args) =>
{
    args.Cancel = true;
    keepRunning = false;
};

var timer = new Timer((consumer) =>
{
    ((EventingConsumer)consumer).SweepWaitingMessage(queueName);
}, consumer, TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30));

try
{
    while (keepRunning)
    {
        consumer.Wait(); // Thread will block here
    }
}
finally
{
    Thread.Sleep(250);
    consumer.CloseChannel();
}


static void HandleMessage(Message message, Action ack, Action<TimeSpan?> nack)
{
    try
    {
        Console.WriteLine(message.Body);
        var deliveryId = message.DeliveryId;
        Console.WriteLine($"Delivery ID: {deliveryId}");
        Thread.Sleep(250);
        if (Random.Shared.NextDouble() < 0.1)
        {
            nack(TimeSpan.FromSeconds(60));
            Console.WriteLine("Message nacked.");
        }
        ack();
        Console.WriteLine("Message acked.");
    }
    catch (Exception e)
    {
        Console.Error.WriteLine(e.Message);
    }
}