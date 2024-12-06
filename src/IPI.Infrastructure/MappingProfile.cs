using AutoMapper;
using IPI.Core.Entities.DictionaryAggregate;
using IPI.Core.Entities.GeographicUnitAggregate;
using IPI.Core.Entities.UrlShortenerAggregate;
using IPI.Dto;
using IPI.Dto.UrlShortenerAggregate;
using System;
using System.Collections.Generic;
using System.Net;
using System.Text;

namespace IPI.Infrastructure
{
    public static class Mapping
    {
        private static readonly Lazy<IMapper> Lazy = new Lazy<IMapper>(() =>
        {
            var config = new MapperConfiguration(cfg =>
            {
                // This line ensures that internal properties are also mapped over.
                cfg.ShouldMapProperty = p => p.GetMethod.IsPublic || p.GetMethod.IsAssembly;
                cfg.AddProfile<MappingProfile>();
            });
            var mapper = config.CreateMapper();
            return mapper;
        });

        public static IMapper Mapper => Lazy.Value;
    }

    public class MappingProfile : Profile
    {
        public MappingProfile()
        {
            CreateMap<Units, UnitsDto>()
                .ForMember(o => o.Id, x => x.MapFrom(z => z.SubId))
                .ForMember(o => o.Name, x => x.MapFrom(z => z.SubName))
                .ForMember(o => o.NameHi, x => x.MapFrom(z => z.SubNameHi))
                .ForMember(o => o.GeoId, x => x.MapFrom(z => z.SubGeoId))
                .ReverseMap();

            CreateMap<IndicatorsDto, Indicators>()
                .ForMember(o => o.Id, x => x.MapFrom(z => z.IndId))
                .ForMember(o => o.Name, x => x.MapFrom(z => z.IndName))
                .ForMember(o => o.NameHi, x => x.MapFrom(z => z.IndNameHi))
                .ForMember(o => o.ReadingStrategy, x => x.MapFrom(z => z.IndReadingStrategy))
                .ReverseMap();

            CreateMap<Division, DivisionDto>()
                .ForMember(o => o.Id, x => x.MapFrom(z => z.Id))
                .ForMember(o => o.Name, x => x.MapFrom(z => z.Name))
                .ForMember(o => o.NameHi, x => x.MapFrom(z => z.NameHi))
                .ForMember(o => o.Parent, x => x.MapFrom(z => new DivisionDto
                { Id = z.ParentId, Name = z.ParentName, NameHi = z.ParentNameHi, Parent = new DivisionDto { Id = z.StateId, Name = z.StateName, NameHi = z.StateNameHi } }))
                .ReverseMap();

            CreateMap<IndicatorDto, Indicator>()
                .ReverseMap();
            CreateMap<ShortenedUrlDto, ShortenedUrl>()
                .ReverseMap();
        }
    }
}
