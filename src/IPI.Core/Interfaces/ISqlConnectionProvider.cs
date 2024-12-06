using System.Data;

namespace IPI.Core.Interfaces
{
    public interface ISqlConnectionProvider
    {
        IDbConnection GetDbConnection();
    }
}