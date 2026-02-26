# Table of Contents
1. [NeoGoDDaR](#neogoddar) <br>
	1.1. [Features](#features) <br>
	1.2. [Workflow](#workflow) <br>
		1.2.3. [Components](#components) <br>
2. [Requirements](#requirements) <br>
	2.1. [Installation](#installation) <br>
3. [Usage](#usage) <br>
	3.1. [Modes of operation](#operation_modes) <br>
	3.2. [Test cases](#test_cases) <br>
		3.2.1. [Example usage](#example_usage) <br>

---

# NeoGoDDaR <a name="neogoddar"></a>
NeoGoDDaR is a tool for static **D**eadlock **D**etection **a**nd **R**esolution in **Go** Programs.

## Features <a name="features"></a>

* Fully automated workflow
* Deadlock analysis with no code annotations required
* Supports the most commonly used Go features
  * Synchronous/Asynchronous channels
  * Channel closing
  * Select statement
  * Recursion/loops
* Deadlock resolution on the original Go code
  * With heuristics to prevent changing the program in undesired ways


## Workflow <a name="workflow"></a>

<p align="center"> <img src="assets/pipeline.svg" alt="NeoGoDDaR pipeline" title="NeoGoDDaR pipeline" /> </p>

The general workflow of the tool is as follows:
From the Go source code (❶), using a slightly modified version of the
[Gospal](https://github.com/GustavoFeio/gospal) program analysis framework (❷) a simpler representation
of the Go program is obtained (❸). From the simpler MiGo representation, our tool translates the MiGo
into the form of a [CCS](https://en.wikipedia.org/wiki/Calculus_of_communicating_systems) expression (❹). 
Over the CCS representation of the Go program, the tool performs static analysis to determine if any
deadlock exists (❺). For each deadlock found, one of two strategies can be applied to resolve the deadlock (❻).
NeoGoDDaR repeats through the deadlock detection and resolution steps (❺ and ❻) until no deadlocks are found.
The resulting resolved program can be returned in CCS form (❼), or, with the help of another tool (❽),
the resolved program can also be return the Go code form (❾).


### Components <a name="components"></a>

* NeoGoDDaR
* fixer
  * Located in the `./fixer` directory
* gospal
  * Located in the following repository https://github.com/GustavoFeio/gospal

# Requirements <a name="requirements"></a>

This approach makes use of components written in OCaml and Go, and as such, the usual minimal development tools are required.
For OCaml, `menhir` parser and the `dune` build system are required to build the NeoGoDDaR tool.
For Go, only the `go` (version 1.18) tool is required.

## Installation <a name="installation"></a>

* Install ocaml/opam/dune/menhir
* Install Go 1.18
  * This specific version of Go is required due to compatibility reasons with the `migoinfer` tool and the fixer aspect. **Make sure any Go commands used for the setup of this tool are done with this version.**
* Build and install migoinfer (included in gospal): https://github.com/GustavoFeio/gospal
  ```
  $ git clone https://github.com/GustavoFeio/gospal.git
  $ cd gospal/cmd/migoinfer/
  $ go install
  ```
  * Make sure the `migoinfer` binary is located in `$PATH`
* Clone NeoGoDDaR git repository
```
$ git clone https://github.com/GustavoFeio/NeoGoDDaR.git
```
* Build NeoGoDDaR
```
$ cd NeoGoDDaR
$ dune build
$ dune exec -- GoDDaR
```
* (Optional) For automatic patching of Go code, installation of the `fixer` program is necessary.
```
$ cd fixer
$ go install GoDDaR_fixer
```
Make sure the resulting `GoDDaR_fixer` executable is in `$PATH`

# Usage <a name="usage"></a>
## Modes of operation <a name="operation_modes"></a>

NeoGoDDaR can analyse programs in three different representations: Go, MiGo and CCS.
The tool has a subcommand to process each representation:
| Representation | Command                   |
|----------------|---------------------------|
| Go             | `GoDDaR go <Go file>`     |
| MiGo           | `GoDDaR migo <MiGo file>` |
| CCS            | `GoDDaR ccs <process>`    |

## Test cases <a name="test_cases"></a>
The `tests/` directory contains two types of benchmarks:
- The benchmark used during development, `examples/`;
- And the benchmark for performance evaluation `go-deadlock-bug-collection/`.

### Example usage <a name="example_usage"></a>

Information about the command-line arguments:
```
$ dune exec -- GoDDaR --help
Usage: ./GoDDaR [-v | -ds ] [ccs <process> | migo <MiGo file> | go [-patch] <Go file>]
  -v Output extra information
  -ds Select deadlock resolution algorithm (1 or 2)
  -help  Display this list of options
  --help  Display this list of options
```

Analyse CCS process:
```
$ dune exec GoDDaR ccs 'a!.b?.0 || b!.a?.0'
---- 1 ----
    (a!.b?.0 || b!.a?.0)

Deadlocks:
---- 1 ----
    (a!.b?.0 || b!.a?.0)
Resolved:
    ((a!.0 || b?.0) || (b!.0 || a?.0))
```

Analyse MiGo type:
```
$ dune exec GoDDaR migo tests/examples/bad_order_circular/main.migo
---- 1 ----
(t0!.t1?.0 || t1!.t0?.0)

Deadlocks:
---- 1 ----
(t0!.t1?.0 || t1!.t0?.0)
Resolved:
((t0!.0 || t1?.0) || (t1!.0 || t0?.0))
```

Analyse Go:
```
$ dune exec -- GoDDaR go -patch tests/examples/double_read/main.go
Program:
	main.main$1[ch, ch1] ::= ch1!.ch?.0;

	(t0!.t1?.0 || main.main$1[t0, t1].0)

Analysis:
--- 1 ---
    (t0!.t1?.0 || main.main$1[t0, t1].0)


Deadlocks:
--- 1 ---
    (t0!.t1?.0 || main.main$1[t0, t1].0)
Fully Resolved:
((t0!.0 || t1?.0) || main.main$1[t0, t1].0)


PARALLELIZE
tests/examples/bad_order_circular/main.go:12:5


--- tests/examples/bad_order_circular/main.go
+++ fixed/tests/examples/bad_order_circular/main.go
@@ -8,6 +8,8 @@
 		ch1 <- "msg"
 		<-ch
 	}(ch, ch1)
-	ch <- 1
+	go func() {
+		ch <- 1
+	}()
 	<-ch1
 }


// This example has a deadlock due to the cyclic dependency on channels `ch` and `ch1`.

package main

func main() {
	ch, ch1 := make(chan int), make(chan string)
	go func(ch chan int, ch1 chan string) {
		ch1 <- "msg"
		<-ch
	}(ch, ch1)
	go func() {
		ch <- 1
	}()
	<-ch1
}
```
