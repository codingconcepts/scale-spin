package apdex

import (
	"math"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestScore(t *testing.T) {
	tests := []struct {
		name      string
		latencies []time.Duration
		want      float64
	}{
		{
			name:      "empty slice",
			latencies: []time.Duration{},
			want:      0,
		},
		{
			name:      "all fast (<=20ms)",
			latencies: []time.Duration{10 * time.Millisecond, 15 * time.Millisecond, 20 * time.Millisecond},
			want:      1.0,
		},
		{
			name:      "all moderate (21-50ms)",
			latencies: []time.Duration{21 * time.Millisecond, 30 * time.Millisecond, 50 * time.Millisecond},
			want:      0.8,
		},
		{
			name:      "all slow (51-75ms)",
			latencies: []time.Duration{51 * time.Millisecond, 60 * time.Millisecond, 75 * time.Millisecond},
			want:      0.6,
		},
		{
			name:      "all slower (76-100ms)",
			latencies: []time.Duration{76 * time.Millisecond, 90 * time.Millisecond, 100 * time.Millisecond},
			want:      0.4,
		},
		{
			name:      "all too slow (>100ms)",
			latencies: []time.Duration{101 * time.Millisecond, 200 * time.Millisecond, 500 * time.Millisecond},
			want:      0.0,
		},
		{
			name: "mixed latencies",
			latencies: []time.Duration{
				10 * time.Millisecond,
				25 * time.Millisecond,
				60 * time.Millisecond,
				90 * time.Millisecond,
				150 * time.Millisecond,
			},
			want: (1.0 + 0.8 + 0.6 + 0.4 + 0.0) / 5,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Score(tt.latencies)
			assert.Equal(t, math.Round(tt.want*100)/100, math.Round(got*100)/100)
		})
	}
}
