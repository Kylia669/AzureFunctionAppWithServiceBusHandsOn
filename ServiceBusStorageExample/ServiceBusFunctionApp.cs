using System;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace ServiceBusStorageExample
{
    public class FunctionMessage
    {
        public DateTime DateTime { get; set; }
        public string Id { get; set; }
    }
    public class ServiceBusFunctionApp
    {
        private readonly ILogger _logger;

        public ServiceBusFunctionApp(ILogger<ServiceBusFunctionApp> logger)
        {
            _logger = logger;
        }

        [FunctionName("QueueTrigger")]
        public void ServiceBusMessageReciever([ServiceBusTrigger("akylfuncappservicebus-input", Connection = "sbConnection")] FunctionMessage message)
        {
            _logger.LogInformation($"Service bus trigger recieved message: {message.Id}-{message.DateTime}");
        }

        [FunctionName("QueueOutput")]
        [return: ServiceBus("akylfuncappservicebus-input", Connection = "sbConnection")]
        public FunctionMessage ServiceBusMessageProducer([HttpTrigger(Microsoft.Azure.WebJobs.Extensions.Http.AuthorizationLevel.Anonymous, "GET",Route = "send-message")] HttpRequest req)
        {
            var message = new FunctionMessage
            {
                DateTime = DateTime.Now,
                Id = Guid.NewGuid().ToString()
            };
            _logger.LogInformation($"Service bus produced message: {message.Id}-{message.DateTime}");
            return message;
        }
    }
}
