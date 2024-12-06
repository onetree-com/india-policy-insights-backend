using System;
using System.Collections.Generic;
using System.Data;
using System.Threading.Tasks;
using Dapper;
using Dapper.Contrib;
using Dapper.Contrib.Extensions;
using IPI.Core.Interfaces;
using IPI.SharedKernel;
using IPI.SharedKernel.Exceptions;
using Serilog;
using static Dapper.SqlMapper;

namespace IPI.Infrastructure.Repositories
{
    public abstract class Repository : IRepository
    {
        private readonly ISqlConnectionProvider _sqlConnectionProvider;

        protected Repository(ISqlConnectionProvider sqlConnectionProvider)
        {
            _sqlConnectionProvider = sqlConnectionProvider;
        }

        public async Task<T> Get<T>(string query)
        {
            Log.Debug($"Raw query: {query}");

            var item = await Execute(db => db.QuerySingleAsync<T>(query)).ConfigureAwait(false);
            Log.Debug($"The query execution was successful, got a result? {item != null}");
            return item;
        }

        public async Task<IList<T>> GetAll<T>(string query)
        {
            Log.Debug($"Raw query: {query}");

            var items = await Execute(db => db.QueryAsync<T>(query)).ConfigureAwait(false);
            var itemList = items.AsList();
            Log.Debug($"The query execution was successful, got {itemList.Count} results");

            return itemList;
        }

        private async Task<T> Execute<T>(Func<IDbConnection, Task<T>> procedure)
        {
            try
            {
                Log.Debug("Creating a connection to the database");
                using (IDbConnection db = _sqlConnectionProvider.GetDbConnection())
                {
                    Log.Debug("The connection to the database was successful");
                    return await procedure.Invoke(db).ConfigureAwait(false);
                }
            }
            catch (Exception exception)
            {
                Log.Error(exception, exception.Message);
                throw new CustomException("An exception was thrown during the connection with the database");
            }
        }

        public async Task<int> Add<T>(T entity) where T : class
        {
            try
            {
                Log.Debug("Creating a connection to the database");
                using (IDbConnection db = _sqlConnectionProvider.GetDbConnection())
                {
                    Log.Debug("The connection to the database was successful");
                    return await db.InsertAsync(entity).ConfigureAwait(false);
                }
            }
            catch (Exception exception)
            {
                Log.Error(exception, exception.Message);
                throw new CustomException("An exception was thrown during the connection with the database");
            }
        }

        public async Task<bool> Update<T>(T entity) where T : class
        {
            try
            {
                Log.Debug("Creating a connection to the database");
                using (IDbConnection db = _sqlConnectionProvider.GetDbConnection())
                {
                    Log.Debug("The connection to the database was successful");
                    return await db.UpdateAsync<T>(entity).ConfigureAwait(false);
                }
            }
            catch (Exception exception)
            {
                Log.Error(exception, exception.Message);
                throw new CustomException("An exception was thrown during the connection with the database");
            }
        }
    }
}