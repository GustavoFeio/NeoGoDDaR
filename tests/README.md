# Tests
This directory contains two benchmarks: `examples/` and `go-deadlock-bug-collection/`.

## Examples
The `examples/` directory contains additional tests used during development to add and validate features as they were being implemented.
The `run_benchmark.sh` script automatically runs all of the test cases and redirects the output to a file in the test case directory under an `*.output` file.
Below is a quick overview of available commands:
```sh
Usage: ./examples/run_benchmark.sh
	[-h|--help]     - Prints the available comands.
	[-v|--verbose]  - Outputs more information about the analysis intermediate representation.
	[-t|--terminal] - Prints the output to the terminal.
	[-c|--clean]    - Cleans any generated `.output` files.
```

## Go Deadlock Bug Collection
The `go-deadlock-bug-collection/` directory contains the tests used to evaluate NeoGoDDaR's performance.
The `run_benchmark.sh` script automatically runs all of the test cases and redirects the output to a file in the test case directory under an `*.output` file.
Below is a quick overview of available commands:
```sh
Usage: ./go-deadlock-bug-collection/run_benchmark.sh
	[-h|--help]     - Prints the available comands.
	[-v|--verbose]  - Outputs more information about the analysis intermediate representation.
	[-t|--terminal] - Prints the output to the terminal.
	[-c|--clean]    - Cleans any generated `.output` files.
```
