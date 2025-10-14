package models

type Scenario string

const (
	// Permanently doubles EU traffic.
	ScenarioScaleUpEU Scenario = "scale-up-eu"

	// Permanently halves EU traffic.
	ScenarioScaleDownEU Scenario = "scale-down-eu"

	// Permanently doubles US traffic.
	ScenarioScaleUpUS Scenario = "scale-up-us"

	// Permanently halves US traffic.
	ScenarioScaleDownUS Scenario = "scale-down-us"

	// Permanently doubles AP traffic.
	ScenarioScaleUpAP Scenario = "scale-up-ap"

	// Permanently halves AP traffic.
	ScenarioScaleDownAP Scenario = "scale-down-ap"

	// Scales global traffic by 10x for 10 minutes.
	ScenarioFlashSale Scenario = "flash-sale"

	// High demand for a new product for 10 minutes.
	ScenarioNewProduct Scenario = "new-product"

	// Halves global traffic down for 10 minutes.
	ScenarioScandal Scenario = "scandal"

	// Tests that messages are reaching service.
	ScenarioTest Scenario = "test"
)
