# Ecto.Paging

[![Deps Status](https://beta.hexfaktor.org/badge/all/github/Nebo15/ecto_paging.svg)](https://beta.hexfaktor.org/github/Nebo15/ecto_paging) [![Build Status](https://travis-ci.org/Nebo15/ecto_paging.svg?branch=master)](https://travis-ci.org/Nebo15/ecto_paging) [![Coverage Status](https://coveralls.io/repos/github/Nebo15/ecto_paging/badge.svg?branch=master)](https://coveralls.io/github/Nebo15/ecto_paging?branch=master)

This module provides a easy way to apply cursor-based pagination to your Ecto Queries.

## Usage:

  1. Add macro to your repo

    ```elixir
    defmodule MyRepo do
      use Ecto.Repo, otp_app: :my_app
      use Ecto.Pagging.Repo # This string adds `paginate/2` and `page/3` methods.
    end
    ```

  2. Paginate!

    ```elixir
    query = from p in Ecto.Paging.Schema

    {res, next_paging} = query
    |> Ecto.Paging.TestRepo.page(%Ecto.Paging{limit: 150})
    ```

## Limitations:

  * Right now it works only with schemas that have `:inserted_at` field with auto-generated value.
  * You need to be careful with order-by's in your queries, since this feature is not tested yet.
  * It doesn't construct `has_more` and `size` counts in `paginate` struct (TODO: add this helpers).
  * When both `starting_after` and `ending_before` is set, only `starting_after` is used.

## Installation

  1. Add `ecto_paging` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ecto_paging, "~> 0.6.0"}]
    end
    ```

  2. Ensure `ecto_paging` is started before your application:

    ```elixir
    def application do
      [applications: [:ecto_paging]]
    end
    ```
