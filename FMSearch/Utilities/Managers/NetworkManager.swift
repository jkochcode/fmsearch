//
//  NetworkManager.swift
//  FMSearch
//
//  Created by Josh Koch on 11/11/20.
//

import Combine
import Foundation

struct TrendingResult: Decodable, Identifiable {
    var id: Int
    var posterPath: String
}

struct Trending {
    let movies: [TrendingResult]
    let shows: [TrendingResult]
}

struct CreditsResponse: Decodable {
    let crew: [Crew]
}

enum MediaType: String {
    case movie = "Movie"
    case tv = "TV"
}

struct NetworkManager {
    static let shared = NetworkManager()

    let baseUrl = "https://api.themoviedb.org/3"
    let apiKey = URLQueryItem(
        name: "api_key", value: "303f034a41d2f1bf014e2a8fcc13e0f9"
    )

    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .formatted(yyyyMMdd)
        return decoder
    }()

    func loadTrending() -> AnyPublisher<Trending, Error> {
        var moviesComponents = URLComponents(
            string: "\(baseUrl)/trending/movie/week")!
        moviesComponents.queryItems = [apiKey]

        var tvComponents = URLComponents(string: "\(baseUrl)/trending/tv/week")!
        tvComponents.queryItems = [apiKey]

        let moviesTrendingPublisher = URLSession.shared.resultsPublisher(
            for: moviesComponents.url!, responseType: [TrendingResult].self,
            decoder: decoder
        )
        let tvTrendingPublisher = URLSession.shared.resultsPublisher(
            for: tvComponents.url!, responseType: [TrendingResult].self,
            decoder: decoder
        )

        return Publishers.Zip(moviesTrendingPublisher, tvTrendingPublisher)
            .map { Trending(movies: $0.0, shows: $0.1) }
            .eraseToAnyPublisher()
    }

    func loadSearch(for query: String, in media: MediaType) -> AnyPublisher<[SearchResult], Error> {
        var components = URLComponents(
            string: "\(baseUrl)/search/\(media.rawValue.lowercased())")!
        components.queryItems = [
            apiKey,
            URLQueryItem(name: "query", value: query)
        ]

        return URLSession.shared.resultsPublisher(
            for: components.url!, decoder: decoder
        )
    }

    func loadMovieDetail(for id: Int) -> AnyPublisher<MovieDetail, Error> {
        var components = URLComponents(string: "\(baseUrl)/movie/\(id)")!
        components.queryItems = [
            apiKey,
            URLQueryItem(name: "append_to_response", value: "credits")
        ]

        return URLSession.shared.publisher(
            for: components.url!, decoder: decoder
        )
    }

    func loadTVDetail(for id: Int) -> AnyPublisher<TVDetail, Error> {
        var components = URLComponents(string: "\(baseUrl)/tv/\(id)")!
        components.queryItems = [
            apiKey,
            URLQueryItem(name: "append_to_response", value: "credits")
        ]

        return URLSession.shared.publisher(
            for: components.url!, decoder: decoder
        )
    }

    func loadCredits(for id: Int, in type: MediaType) -> AnyPublisher<[Crew], Error> {
        var components = URLComponents(
            string: "\(baseUrl)/\(type.rawValue)/\(id)/credits")!
        components.queryItems = [apiKey]

        return URLSession.shared.dataTaskPublisher(for: components.url!)
            .map(\.data)
            .decode(type: CreditsResponse.self, decoder: decoder)
            .map(\.crew)
            .eraseToAnyPublisher()
    }
}
