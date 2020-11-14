# FSH Finder 🐟🔭

Script to find GitHub repositories that contain [FSH](https://fshschool.org) code.

## Data sources

Git repositories containing FHIR Implementation Guides are found from the following sources:
  
1. [FHIR continuous integration build list](https://fhir.github.io/auto-ig-builder/builds.html)
1. Specific GitHub organizations/users known to contain IGs ([see `RepoSourceGitHubOrgs` in `lib/repo_sources.rb`][repo_sources.rb])
1. A static list of manually defined repos ([see `RepoSourceStatic` in `lib/repo_sources.rb`][repo_sources.rb])

FSH is identified by looking for the presence of the following folders in _any_ branch of the repository that is public on GitHub:

- **FSH supporting SUSHI >= 1.0**: `/input/fsh/`
- **FSH supporting SUSHI < 1.0**: `/fsh/`

FSH language features (instantiation of Profiles, Instances, OperationDefinition instances, and StructureDefinition instances)  only include the primary branch in the IG's GitHub repository. This is due to the GitHub search API only indexing the primary branch. See [`lib/features.rb`][features.rb] for details.

## Running

1. [Install Ruby](https://www.ruby-lang.org/en/documentation/installation/).
2. [Install Bundler](https://bundler.io).
3. Clone this repo locally.
4. Run `bundle install` from the root of the repo.
5. Copy `env.example` to `.env`, get a [personal access token for GitHub](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token), and put that along with your username into `.env`. This is necessary to avoid aggressive rate limiting for unauthenticated users with the GitHub search API.
6. Run `script/run`, which will populate the `generated/` folder with output:
    - `generated/index.html` is the main product of the script; based on `template.liquid`
    - `generated/fshy_repos.txt` is a list of the GitHub URLs for repos using FSH
    - `generated/cache.json` is a structured representation of the data used to create `index.html`
    
    Note that a clean run of `script/run` can take >10 minutes.
  
### Caching

By default `script/run` will use `generated/cache.json` if it exists rather than re-querying the GitHub API on every run. This allows for iterative modifications to `index.html`. Run `script/clean` to remove the cache and other contents of `generated/`.

## Publishing

Run `script/publish`.

[repo_sources.rb]: https://github.com/FSHSchool/fsh-finder/blob/main/lib/repo_sources.rb
[features.rb]: https://github.com/FSHSchool/fsh-finder/blob/main/lib/features.rb

## License

Copyright 2020 The MITRE Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
  
  