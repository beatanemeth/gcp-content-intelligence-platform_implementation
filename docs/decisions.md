# Decisions

The main design decisions, one table per topic. The full reasoning lives in the [planning repository](https://github.com/beatanemeth/gcp-content-intelligence-platform_planning).

<br>

## The story

| Decision                                                                                       | Why                                                                                         | What it costs                                                                    |
| ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| **Part A and Part B:** the platform (Part A) is separate from the pipeline feature (Part B)    | Mirrors a real company: a platform team runs the shared basics; a feature team adds to them | Part B depends on values it does not create; they must be handed over and agreed |
| **Ownership rule:** "Would a second feature need it?" Yes: Part A. No: Part B                  | One clear test decides where each resource belongs                                          | Shared items such as the enabled APIs stay outside the module                    |
| **Part B changes nothing in Part A:** it only adds its own resources and permissions           | The feature can be added and removed without risk to other features                         | The module cannot enable APIs or fix a missing platform setting itself           |

<br>

## Simulation

| Decision                                                                                  | Why                                                                   | What it costs                                                                          |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **Simulation instead of real GCP:** a mocked Google provider, a BigQuery emulator, fakes | No GCP project is needed; every check runs on the laptop and in CI    | Simulated results can differ from real GCP; a real deployment (step 9) confirms them |
| **Labelled results:** every simulated result says so                                     | A reader never mistakes a laptop check for a cloud result             | More wording in the docs                                                               |
