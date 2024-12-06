using System;
using System.Net;
using System.Runtime.Serialization;
using System.Security.Permissions;

namespace IPI.SharedKernel.Exceptions
{
    [Serializable]
    public class CustomException : Exception
    {
        public CustomException()
        {
        }

        public CustomException(string message)
            : base(message)
        {
        }

        public CustomException(string message, Exception innerException)
            : base(message, innerException)
        {
        }

        public CustomException(string code, HttpStatusCode statusCode, string message) : base(message)
        {
            Code = code;
            StatusCode = statusCode;
        }

        public CustomException(string code, HttpStatusCode statusCode, string message, Exception innerException)
            : base(message, innerException)
        {
            Code = code;
            StatusCode = statusCode;
        }

        [SecurityPermissionAttribute(SecurityAction.Demand, SerializationFormatter = true)]
        // Constructor should be protected for unsealed classes, private for sealed classes.
        // (The Serializer invokes this constructor through reflection, so it can be private)
        protected CustomException(SerializationInfo info, StreamingContext context)
            : base(info, context)
        {
            if (info == null)
            {
                return;
            }

            Code = info.GetString("Code");
            StatusCode = (HttpStatusCode)info.GetValue("StatusCode", typeof(HttpStatusCode));
        }

        public string Code { get; set; }
        public HttpStatusCode StatusCode { get; set; }

        public override void GetObjectData(SerializationInfo info, StreamingContext context)
        {
            if (info == null)
            {
                throw new ArgumentNullException("info");
            }

            info.AddValue("Code", this.Code);
            info.AddValue("StatusCode", this.StatusCode);

            base.GetObjectData(info, context);
        }
    }
}
