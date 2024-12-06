using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using IPI.Core.Entities.DictionaryAggregate;
using IPI.Core.Interfaces;
using IPI.Functions.Models;
using IPI.SharedKernel.Exceptions;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Serilog;

namespace IPI.Functions.DictionaryAggregate
{
    public class GetCategories : BaseFunction
    {
        private readonly IDictionaryRepository _repository;

        public GetCategories(IDictionaryRepository repository)
        {
            _repository = repository;
        }

        [FunctionName(nameof(GetCategories))]
        public async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous, nameof(HttpMethods.Get), Route = "dictionary/categories")] HttpRequest request)
        {
            try
            {
                Log.Debug("Handling request for available categories");
                var results = await _repository.GetCategories().ConfigureAwait(false);

                var parents = results.Where(cat => !cat.ParentId.HasValue).ToList();
                var children = results.Where(cat => cat.ParentId.HasValue).ToList();

                var categories = GetCategoriesWithItsSubcategories(parents, children);

                Log.Debug("Procedure ended successfully");
                return categories.Any() ? Ok(categories) : Error(System.Net.HttpStatusCode.NoContent, $"No categories where found");
            }
            catch (CustomException exception)
            {
                Log.Error(exception, exception.Message);
                return Error(System.Net.HttpStatusCode.BadRequest, exception.Message);
            }
            catch (Exception exception)
            {
                Log.Error(exception, exception.Message);
                return Error(System.Net.HttpStatusCode.BadRequest, "");
            }
        }

        private IEnumerable<CategoryDto> GetCategoriesWithItsSubcategories(IEnumerable<Categories> categories, IEnumerable<Categories> subcategories)
            => categories
                    .GroupJoin(subcategories,
                               cat => cat.Id,
                               sub => sub.ParentId,
                               (category, subcategory) => (category, subcategory))
                    .Select(group =>
                    {
                        var children = group.subcategory.Select(item => new CategoryDto { Id = item.Id, Name = item.Name });
                        return new CategoryDto
                        {
                            Id = group.category.Id,
                            Name = group.category.Name,
                            Subcategories = children
                        };
                    }).ToList();
    }
}

