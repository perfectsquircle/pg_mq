using System.Text.Json.Nodes;
using System.Text.Json.Serialization;

namespace Example;

public class Message
{
    [JsonPropertyName("delivery_id")]
    public long DeliveryId { get; set; }
    [JsonPropertyName("routing_key")]
    public string RoutingKey { get; set; }
    [JsonPropertyName("body")]
    public JsonNode Body { get; set; }
    [JsonPropertyName("headers")]
    public Dictionary<string, string> Headers { get; set; }
}