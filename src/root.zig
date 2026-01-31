const std = @import("std");

pub fn parseCsv(allocator: std.mem.Allocator, path: []const u8) !std.MultiArrayList(Schema) {
    // Returns an OWNED std.MultiArrayList
    //
    var buf: [4096]u8 = undefined;

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var huh = file.reader(&buf);
    var reader = &huh.interface;

    const headers = (try reader.takeDelimiter('\n')).?;
    std.debug.print("{s}\n", .{headers});

    var values = std.MultiArrayList(Schema){};
    const types = [_]Dtype{ .string, .int, .string };

    while (try reader.takeDelimiter('\n')) |line| {
        var fields = std.ArrayList([]const u8){};
        var tokens = std.mem.tokenizeSequence(u8, line, ",");
        while (tokens.next()) |token| {
            try fields.append(allocator, token);
        }

        var parsedValues = std.ArrayList(Value){};
        defer parsedValues.deinit(allocator);

        for (fields.items, types) |value, dtype| {
            switch (dtype) {
                .int => {
                    const parsed = try std.fmt.parseInt(i32, value, 10);
                    try parsedValues.append(allocator, Value{ .int = parsed });
                },
                .float => {
                    const parsed = try std.fmt.parseFloat(f32, value);
                    try parsedValues.append(allocator, Value{ .float = parsed });
                },
                .string => {
                    try parsedValues.append(allocator, Value{ .string = value });
                },
            }
        }

        try values.append(allocator, .{
            .name = parsedValues.items[0].string,
            .age = @intCast(parsedValues.items[1].int),
            .city = parsedValues.items[2].string,
        });
    }

    return values;
}

// Expected headers types

const Schema = struct {
    name: []const u8,
    age: usize,
    city: []const u8,
};

const Dtype = enum { int, float, string };
const Value = union(Dtype) {
    int: i32,
    float: f32,
    string: []const u8,
};
