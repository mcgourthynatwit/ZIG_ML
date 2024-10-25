# ZigML: Data Analysis and Machine Learning in Zig

A performant and memory-efficient data analysis and machine learning library written in Zig.

## Features
### Table Operations
- CSV reading
- Dataframe object
- DataFrame filtering
- DataFrame to Tensor for machine learning

### Machine Learning
- Linear Models
- OLS Regression
- [In development] Lasso Regression
- [In development] Ridge Regression

## Installation
```bash
git clone https://github.com/mcgourthynatwit/ZIG_ML.git
cd ZIG_ML
zig build
```

## Quick Start
```zig
const std = @import("std");
const Table = @import("csv.zig").Table;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
  
    // Initialize and read CSV file
    var table: Table = Table.init(allocator);
    try table.readCsv("data.csv");
    defer table.deinit();

    // Display the first 5 rows of the table
    try table.head();
}

```
