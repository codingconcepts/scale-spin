package apdex

import "time"

func Score(latencies []time.Duration) float64 {
	if len(latencies) == 0 {
		return 0
	}

	var total float64
	for _, d := range latencies {
		ms := d.Milliseconds()
		switch {
		case ms <= 20:
			total += 1.0
		case ms <= 50:
			total += 0.8
		case ms <= 75:
			total += 0.6
		case ms <= 100:
			total += 0.4
		default:
			total += 0.0
		}
	}

	return total / float64(len(latencies))
}
