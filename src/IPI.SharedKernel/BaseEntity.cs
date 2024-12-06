using System;

[assembly: System.Runtime.InteropServices.ComVisible(false)]
[assembly: CLSCompliant(false)]
namespace IPI.SharedKernel
{
    public abstract class BaseEntity
    {
        public int Id { get; set; }
    }
}
