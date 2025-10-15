# scale-spin
Roulette but for database scaling.

Scales a potentially global workload up and down and the database must keep up to provide the best possible Application Performance Index (Apdex) score which will be calculated based on the following latency map:

| Latency  | Apdex Score | Meaning      |
| -------  | ----------- | ------------ |
| <= 20ms  | 0.94 - 1.0  | Excellent    |
| <= 50ms  | 0.85 - 0.93 | Good         |
| <= 75ms  | 0.70 - 0.84 | Fair         |
| <= 100ms | 0.69 - 0.50 | Poor         |
| >  100ms | 0.00 - 0.49 | Unacceptable |

Once the wheel has landed on a scenario, the database has 10 minutes to scale for that workload. Failure to do so, will result in a low Apdex score.

### Prerequisites

AWS

```sh
aws configure

# Or for SSO
aws configure sso
```

Docker

```sh
docker login
```

Terraform

```sh
(cd infra && terraform init)
```

### Setup

Build and deploy workload image

```sh
docker buildx build \
--platform linux/amd64 \
--build-context pkg=apps/pkg \
-f apps/workload/Dockerfile \
-t codingconcepts/workload:v0.1.0 \
.

docker push codingconcepts/workload:v0.1.0
```

Infra

```sh
(cd infra && terraform apply --auto-approve)
```

Export environment variables

```sh
export AP_SERVICE_URL=$(cd infra && terraform output --json service_urls | jq -r '.["asia-southeast1"]')
export EU_SERVICE_URL=$(cd infra && terraform output --json service_urls | jq -r '.["europe-west2"]')
export US_SERVICE_URL=$(cd infra && terraform output --json service_urls | jq -r '.["us-east1"]')
```

### Demo

Create objects and insert data

```sh
cockroach sql --url $(cd infra && terraform output --raw cockroachdb_global_url) \
--execute "CREATE TABLE workload (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  region STRING NOT NULL,
  workers INT NOT NULL DEFAULT 0
)"

cockroach sql --url $(cd infra && terraform output --raw cockroachdb_global_url) \
--execute "INSERT INTO workload (region, workers) VALUES
             ('gcp-asia-southeast1', 0),
             ('gcp-europe-west2', 0),
             ('gcp-us-east1', 0)"

cockroach sql --url $(cd infra && terraform output --raw cockroachdb_global_url) \
--execute "CREATE TABLE account (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  balance DECIMAL NOT NULL
)"

cockroach sql --url $(cd infra && terraform output --raw cockroachdb_global_url) \
--execute "INSERT INTO account (balance)
  SELECT ROUND(random() * 10000, 2)
  FROM generate_series(1, 1000)"
```

Monitor service logs

```sh

gcloud beta run services logs read crdb-scale-spin --region asia-southeast1 --limit 10
gcloud beta run services logs read crdb-scale-spin --region europe-west2 --limit 10
gcloud beta run services logs read crdb-scale-spin --region us-east1 --limit 10
```

Fetch Apdex scores

```sh
curl -s "${AP_SERVICE_URL}/apdex"
curl -s "${EU_SERVICE_URL}/apdex"
curl -s "${US_SERVICE_URL}/apdex"
```

Spin the wheel!

```sh
go run apps/wheel/main.go \
--url $(cd infra && terraform output --raw cockroachdb_global_url)
```

Update infrastructure to make CockroachDB multi-region

```sh
(cd infra && terraform apply --auto-approve)
```

Alter table locality

```sh
cockroach sql --url $(cd infra && terraform output --raw cockroachdb_global_url) \
--execute "ALTER DATABASE bank SET PRIMARY REGION 'gcp-europe-west2'"

cockroach sql --url $(cd infra && terraform output --raw cockroachdb_global_url) \
--execute "ALTER DATABASE bank ADD REGION 'gcp-us-east1'"

cockroach sql --url $(cd infra && terraform output --raw cockroachdb_global_url) \
--execute "ALTER DATABASE bank ADD REGION 'gcp-asia-southeast1'"

cockroach sql --url $(cd infra && terraform output --raw cockroachdb_global_url) \
--execute "ALTER TABLE account SET LOCALITY REGIONAL BY ROW"

cockroach sql --url $(cd infra && terraform output --raw cockroachdb_global_url) \
--execute "UPDATE account
  SET crdb_region = CASE 
      WHEN random() < 0.33 THEN 'gcp-asia-southeast1'
      WHEN random() < 0.66 THEN 'gcp-europe-west2'
      ELSE 'gcp-us-east1'
  END"
```

Build MR application

```sh
docker buildx build \
--platform linux/amd64 \
--build-context pkg=apps/pkg \
-f apps/workload/Dockerfile \
-t codingconcepts/workload:v0.1.0 \
.

docker push codingconcepts/workload:v0.1.0
```

Update infrastructure to publish multi-region application.

```sh
(cd infra && terraform apply --auto-approve)
```

Fetch Apdex scores

```sh
curl -s "${AP_SERVICE_URL}/apdex"
curl -s "${EU_SERVICE_URL}/apdex"
curl -s "${US_SERVICE_URL}/apdex"
```

### Summary

Run local worker  

```sh

```

### Teardown

Infra

```sh
(cd infra && terraform destroy --auto-approve)
```

Local images

```sh
docker rmi $(docker images codingconcepts/workload -q) -f
docker rmi $(docker images us-east1-docker.pkg.dev/cockroach-rob/scale-spin-workload/codingconcepts/workload -q) -f
```

### Scratchpad

Export environment variables

```sh
export DATABASE_URL=$(cd infra && terraform output --raw cockroachdb_global_url)
export DATABASE_DRIVER="pgx"
export REGION="gcp-europe-west2"
```

Test deployed service

```sh
curl -s "${EU_APP_URL}/healthz"
curl -s "${EU_APP_URL}/messages" --json '{"scenario": "test"}'
curl -s "${EU_APP_URL}/messages" --json '{"scenario": "scale-up-eu"}'
```

Test binary locally

```sh
go run apps/workload/main.go

curl -s http://localhost:8080/healthz
```

Test image locally

```sh
docker run --rm -it codingconcepts/workload
```

View busiest queries of the last 10 minutes

```sh
cockroach sql --url $(cd infra && terraform output --raw cockroachdb_global_url) \
--execute "SELECT 
    metadata->>'query' AS query,
    metadata->>'db' AS database,
    (statistics->'runLat') AS mean_latency_seconds
FROM 
    crdb_internal.statement_statistics
WHERE
     metadata->>'db' = 'defaultdb'
ORDER BY 
    (statistics->>'cnt')::INT DESC
LIMIT 10"

```