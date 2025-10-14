package queue

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/codingconcepts/scale-spin/apps/pkg/models"
)

type SQSReader struct {
	client   *sqs.Client
	queueURL string
}

func NewSQSReader(ctx context.Context, queueURL string) (*SQSReader, error) {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	return &SQSReader{
		client:   sqs.NewFromConfig(cfg),
		queueURL: queueURL,
	}, nil
}

func (r *SQSReader) Run(ctx context.Context, messageQueue chan<- models.Message) error {
	log.Println("starting SQS reader...")

	for {
		select {
		case <-ctx.Done():
			log.Println("stopping SQS reader...")
			return ctx.Err()

		default:
			messages, err := r.receiveMessages(ctx, 10)
			if err != nil {
				log.Printf("error receiving messages: %v", err)
				time.Sleep(5 * time.Second)
				continue
			}

			if len(messages) == 0 {
				log.Println("no messages received, polling again...")
				continue
			}

			log.Printf("received %d message(s)", len(messages))

			for _, msg := range messages {
				messageQueue <- models.Message{
					Scenario: models.Scenario(*msg.Body),
					Delete: func() error {
						return r.deleteMessage(ctx, msg.ReceiptHandle)
					},
				}
			}
		}
	}
}

func (r *SQSReader) receiveMessages(ctx context.Context, maxMessages int32) ([]types.Message, error) {
	result, err := r.client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
		QueueUrl:            aws.String(r.queueURL),
		MaxNumberOfMessages: maxMessages,
		WaitTimeSeconds:     10,
		VisibilityTimeout:   30,
		MessageAttributeNames: []string{
			string(types.QueueAttributeNameAll),
		},
	})

	if err != nil {
		return nil, fmt.Errorf("failed to receive messages: %w", err)
	}

	return result.Messages, nil
}

func (r *SQSReader) deleteMessage(ctx context.Context, receiptHandle *string) error {
	_, err := r.client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
		QueueUrl:      aws.String(r.queueURL),
		ReceiptHandle: receiptHandle,
	})

	if err != nil {
		return fmt.Errorf("failed to delete message: %w", err)
	}

	return nil
}
