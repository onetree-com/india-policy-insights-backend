using Newtonsoft.Json;
using System.Net.Http;
using System.Text;

namespace IPI.Functions
{
    public abstract class BaseFunction
    {
        public HttpResponseMessage Ok(object value)
        {
            var json = JsonConvert.SerializeObject(value);
            return new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            };
        }

        public HttpResponseMessage Error(System.Net.HttpStatusCode statusCode, string message)
        {
            return new HttpResponseMessage(statusCode)
            {
                Content = new StringContent(message)
            };
        }
    }
}
