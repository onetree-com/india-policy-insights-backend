using System.Data;
using Npgsql;

namespace IPI.Infrastructure.Providers
{
    public class PgsqlConnectionProvider : SqlConnectionProvider
    {
        public PgsqlConnectionProvider(string connectionString) : base(connectionString)
        {
        }

        public override IDbConnection GetDbConnection()
        {
            return new NpgsqlConnection(_connectionString);
        }
    }
}