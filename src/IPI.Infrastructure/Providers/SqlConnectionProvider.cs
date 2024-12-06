using System.Data;
using IPI.Core.Interfaces;

namespace IPI.Infrastructure.Providers
{
    public abstract class SqlConnectionProvider : ISqlConnectionProvider
    {
        protected readonly string _connectionString;

        protected SqlConnectionProvider(string connectionString)
        {
            _connectionString = connectionString;
        }

        public abstract IDbConnection GetDbConnection();
    }
}