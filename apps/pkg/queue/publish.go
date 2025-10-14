package queue

import (
	"context"
	"fmt"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/codingconcepts/scale-spin/apps/pkg/models"
)

type SQSPublishers struct {
	publishers []*SQSPublisher
}

type SQSPublisher struct {
	client *sqs.Client
	url    string
	region string
}

func NewSQSPublishers(ctx context.Context, queues []string) (*SQSPublishers, error) {
	var publishers SQSPublishers

	for _, queue := range queues {
		region := extractRegionFromQueueURL(queue)

		cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
		if err != nil {
			return nil, fmt.Errorf("failed to load AWS config for region %s: %w", region, err)
		}

		client := sqs.NewFromConfig(cfg)

		p := SQSPublisher{
			client: client,
			region: region,
			url:    queue,
		}

		publishers.publishers = append(publishers.publishers, &p)
	}

	return &publishers, nil
}

func (p *SQSPublishers) Publish(ctx context.Context, scenario models.Scenario) error {
	for _, p := range p.publishers {
		input := sqs.SendMessageInput{
			MessageBody: aws.String(string(scenario)),
			QueueUrl:    aws.String(p.url),
		}

		if _, err := p.client.SendMessage(ctx, &input); err != nil {
			return fmt.Errorf("publishing to %s: %w", p.region, err)
		}
	}

	return nil
}

func extractRegionFromQueueURL(queueURL string) string {
	parts := strings.Split(queueURL, ".")
	if len(parts) >= 3 && parts[0] == "https://sqs" {
		return parts[1]
	}

	return ""
}
