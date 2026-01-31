# iguanas

A lightweight DataFrame library for Zig, providing CSV parsing and data transformation capabilities.

## Features

- Parse CSV files into typed data structures
- Transform DataFrames with custom mapping functions
- Add rows dynamically
- Memory-safe string handling with automatic cleanup
- Compatible with Zig 0.15.2

## Requirements

- Zig 0.15.2 or later
- [zig-string](https://github.com/JakubSzark/zig-string) (used for memory-safe string handling because I couldn't figure out how to properly deallocate slices)

## Installation

Add `iguanas` as a dependency in your `build.zig.zon`:

```zig
.{
    .name = "your-project",
    .version = "0.0.1",
    .dependencies = .{
        .iguanas = .{
            .url = "https://github.com/matwate/iguanas/archive/main.tar.gz",
            .hash = "...",
        },
    },
}
```

## Usage

### Basic CSV Parsing

Define a schema matching your CSV structure:

```zig
const Schema = struct {
    name: iguanas.String,
    age: usize,
    city: iguanas.String,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{s}, {d}, {s}", .{ self.name.str(), self.age, self.city.str() });
    }
};
```

Load a CSV file:

```zig
var df = try iguanas.DataFrame(Schema).fromCsv(allocator, "data.csv");
defer df.deinit();

for (df.values.items) |*row| {
    std.debug.print("{f}\n", .{row});
}
```

### Adding Rows

```zig
try df.addRow(.{
    .name = try iguanas.String.init_with_contents(allocator, "New Name"),
    .age = 30,
    .city = try iguanas.String.init_with_contents(allocator, "New City"),
});
```

### Transforming DataFrames

```zig
const NewSchema = struct {
    nameCity: iguanas.String,
    
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{s}", .{self.nameCity.str()});
    }
};

const transform = struct {
    fn new(alloc: ?std.mem.Allocator, row: Schema) ?NewSchema {
        // Your transformation logic here
        return NewSchema{ /* ... */ };
    }
}.new;

var newDf = try iguanas.DataFrame(NewSchema).fromDf(allocator, Schema, df, transform);
defer newDf.deinit();
```

## Example

See `src/main.zig` for a complete working example demonstrating CSV parsing, row addition, and data transformation.

## Memory Management

All DataFrames must be deinitialized when no longer needed:

```zig
defer df.deinit();
```

This properly cleans up all allocated memory, including String fields.

## Inspiration

This project was inspired by [ziframe](https://github.com/mtoohey31/ziframe) and other dataframe libraries.

## License

MIT
