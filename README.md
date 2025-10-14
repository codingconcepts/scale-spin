# scale-spin
Roulette but for database scaling.

Scales a potentially global workload up and down and the database must keep up to provide the best possible Application Performance Index (Apdex) score which will be calculated based on the following latency map:

| Latency  | Apdex Score  |
| -------  | -----------  |
| <= 20ms  | Excellent    |
| <= 50ms  | Good         |
| <= 75ms  | Fair         |
| <= 100ms | Poor         |
| >  100ms | Unacceptable |

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
-t codingconcepts/workload:v0.3.0 \
.

docker push codingconcepts/workload:v0.3.0
```

Infra

```sh
(cd infra && terraform apply --auto-approve)
```

### Demo

Connect to CockroachDB

```sh
cockroach sql --url $(cd infra && terraform output --raw cockroachdb_global_url)
```

Create objects and insert data

```sql
CREATE TABLE account (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  balance DECIMAL NOT NULL
);

INSERT INTO account (balance)
  SELECT ROUND(random() * 10000, 2)
  FROM generate_series(1, 10000);
```

Spin the wheel!

```sh
AWS_PROFILE="rob-sso-crlshared" \
US_SQS_QUEUE_URL=$(cd infra && terraform output --json sqs_queue_urls | jq -r '.us_east_1') \
EU_SQS_QUEUE_URL=$(cd infra && terraform output --json sqs_queue_urls | jq -r '.eu_west_2') \
AP_SQS_QUEUE_URL=$(cd infra && terraform output --json sqs_queue_urls | jq -r '.ap_southeast_1') \
go run apps/wheel/main.go
```

### Summary



### Teardown

Purge queues

```sh
aws sqs purge-queue --queue-url $(cd infra && terraform output --json sqs_queue_urls | jq -r '.us_east_1') --region us-east-1

aws sqs purge-queue --queue-url $(cd infra && terraform output --json sqs_queue_urls | jq -r '.eu_west_2') --region eu-west-2

aws sqs purge-queue --queue-url $(cd infra && terraform output --json sqs_queue_urls | jq -r '.ap_southeast_1') --region ap-southeast-1
```

Infra

```sh
(cd infra && terraform destroy --auto-approve)
```

### Scratchpad

Test image locally

```sh
docker run --rm -it codingconcepts/workload
```

Test SQS

```sh
curl -s http://crdb-scale-spin-alb-eu-1813114863.eu-west-2.elb.amazonaws.com \
--json '{ "scenario": "test" }'
```