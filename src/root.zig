const std = @import("std");
pub const String = @import("string").String;

pub fn DataFrame(comptime Schema: type) type {
    if (!(@typeInfo(Schema) == .@"struct")) {
        @compileError("Columns must be of type struct, found " ++ @typeName(Schema));
    }
    return struct {
        values: std.ArrayList(Schema),

        allocator: std.mem.Allocator,
        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .values = std.ArrayList(Schema){},
                .allocator = allocator,
            };
        }

        pub fn fromCsv(allocator: std.mem.Allocator, path: []const u8, hasHeader: bool) !Self {
            var buf: [4096]u8 = undefined;
            const file = try std.fs.cwd().openFile(path, .{});
            defer file.close();

            var huh = file.reader(&buf);
            var reader = &huh.interface;

            var df = Self.init(allocator);
            errdefer df.deinit();

            // Skip the header
            if (hasHeader) {
                _ = try reader.takeDelimiter('\n');
            }
            while (try reader.takeDelimiter('\n')) |line| {
                var row: Schema = undefined;
                const trimmed = std.mem.trim(u8, line, "\r");
                var row_it = std.mem.tokenizeSequence(u8, trimmed, ",");

                var i: usize = 0;
                inline for (std.meta.fields(Schema)) |field| {
                    const token = row_it.next() orelse return error.MissingField;
                    if (@typeInfo(field.type) == .int) {
                        @field(row, field.name) = try std.fmt.parseInt(field.type, token, 10);
                    } else if (@typeInfo(field.type) == .float) {
                        @field(row, field.name) = try std.fmt.parseFloat(field.type, token);
                    } else if (field.type == String) {
                        const fieldString = try String.init_with_contents(allocator, token);
                        @field(row, field.name) = fieldString;
                    }

                    i += 1;
                }

                try df.values.append(df.allocator, row);
            }

            return df;
        }

        pub fn fromDf(allocator: std.mem.Allocator, comptime otherSchema: type, other: DataFrame(otherSchema), transform: *const fn (?std.mem.Allocator, otherSchema) ?Schema) !Self {
            var df = Self.init(allocator);
            errdefer df.deinit();

            for (other.values.items) |*v| {
                const value = transform(df.allocator, v.*) orelse continue;
                try df.addRow(value);
            }
            return df;
        }

        pub fn addRow(self: *Self, values: Schema) !void {
            try self.values.append(self.allocator, values);
        }

        pub fn deinit(self: *Self) void {
            for (self.values.items) |*row| {
                inline for (std.meta.fields(Schema)) |field| {
                    if (field.type == String) {
                        var str = &@field(row, field.name);
                        str.deinit();
                    }
                }
            }
            self.values.deinit(self.allocator);
        }

        pub fn print(self: *Self, from: usize, to: usize) !void {
            if (@hasDecl(Schema, "format")) {
                for (self.values.items[from..to]) |*v| {
                    std.debug.print("{f}\n", .{v.*});
                }
            } else {
                @compileError("Schema doesn't have a format function. If TrainTestSplit was used, the field names are lost, idk how to fix this yet");
            }
        }

        pub fn head(self: *const Self, number: ?usize) !void {
            const rownum = number orelse 5;
            const fields = std.meta.fields(Schema);
            const isTuple = @typeInfo(Schema) == .@"struct" and std.meta.fields(Schema)[0].name[0] >= '0' and std.meta.fields(Schema)[0].name[0] <= '9';

            var stdoutBuf: [4096]u8 = undefined;
            var stdout = std.fs.File.stdout().writer(&stdoutBuf);
            var writer = &stdout.interface;

            // Print header (only if not a tuple)
            if (!isTuple) {
                inline for (fields, 0..) |field, i| {
                    if (i > 0) try writer.writeAll("  ");
                    try writer.print("{s: <10}", .{field.name});
                }
                try writer.writeAll("\n");

                // Print separator line
                inline for (fields, 0..) |_, i| {
                    if (i > 0) try writer.writeAll("  ");
                    try writer.writeAll("----------");
                }
                try writer.writeAll("\n");
            }

            // Print first N rows
            const limit = @min(rownum, self.values.items.len);
            for (self.values.items[0..limit]) |row| {
                inline for (fields, 0..) |field, i| {
                    if (i > 0) try writer.writeAll("  ");

                    const value = @field(row, field.name);
                    if (@typeInfo(field.type) == .int or @typeInfo(field.type) == .float) {
                        try writer.print("{d: <10}", .{value});
                    } else if (field.type == String) {
                        // String type from zig-string has a str() method
                        const str_val: String = value;
                        try writer.print("{s: <10}", .{str_val.str()});
                    } else {
                        // Fallback for other types
                        try writer.print("{}       ", .{value});
                    }
                }
                try writer.writeAll("\n");
            }
            try writer.flush();
        }

        pub fn tail(self: *Self, number: ?usize) !void {
            const rownum = number orelse 5;
            const fields = std.meta.fields(Schema);
            const isTuple = @typeInfo(Schema) == .@"struct" and std.meta.fields(Schema)[0].name[0] >= '0' and std.meta.fields(Schema)[0].name[0] <= '9';

            var stdoutBuf: [4096]u8 = undefined;
            var stdout = std.fs.File.stdout().writer(&stdoutBuf);
            var writer = &stdout.interface;

            // Print header (only if not a tuple)
            if (!isTuple) {
                inline for (fields, 0..) |field, i| {
                    if (i > 0) try writer.writeAll("  ");
                    try writer.print("{s: <10}", .{field.name});
                }
                try writer.writeAll("\n");

                // Print separator line
                inline for (fields, 0..) |_, i| {
                    if (i > 0) try writer.writeAll("  ");
                    try writer.writeAll("----------");
                }
                try writer.writeAll("\n");
            }

            // Print last N rows
            const start = if (self.values.items.len > rownum)
                self.values.items.len - rownum
            else
                0;

            for (self.values.items[start..]) |row| {
                inline for (fields, 0..) |field, i| {
                    if (i > 0) try writer.writeAll("  ");

                    const value = @field(row, field.name);
                    if (@typeInfo(field.type) == .int or @typeInfo(field.type) == .float) {
                        try writer.print("{d: <10}", .{value});
                    } else if (field.type == String) {
                        // String type from zig-string has a str() method
                        const str_val: String = value;
                        try writer.print("{s: <10}", .{str_val.str()});
                    } else {
                        // Fallback for other types
                        try writer.print("{}       ", .{value});
                    }
                }
                try writer.writeAll("\n");
            }
            try writer.flush();
        }
    };
}

pub fn inferSchema(path: []const u8) !void {
    // Prints a possible dataframe  schema so you don't have to write it yousef.
    var buf: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var huh = file.reader(&buf);
    var reader = &huh.interface;

    const header = try reader.takeDelimiter('\n');
    const firstValue = try reader.takeDelimiter('\n');

    var stdoutBuf: [4096]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdoutBuf);

    var writer = &stdout.interface;

    try writer.print("const Schema = struct{{\n", .{});

    try writer.flush();

    const trimmed = std.mem.trim(u8, header.?, "\r");
    const firstValuesTrimmed = std.mem.trim(u8, firstValue.?, "\r");
    var header_it = std.mem.tokenizeSequence(u8, trimmed, ",");
    var firstValues_it = std.mem.tokenizeSequence(u8, firstValuesTrimmed, ",");

    while (header_it.next()) |name| {
        const value = firstValues_it.next();
        if (value) |val| {
            const unquoted_name = std.mem.trim(u8, name, "\"");
            try writer.print("\t{s}: ", .{unquoted_name});
            // Figure out if it's an int, a float or a string as a default
            _ = std.fmt.parseFloat(f32, val) catch {
                _ = std.fmt.parseInt(i32, val, 10) catch {
                    try writer.print("String,\n", .{});
                    continue;
                };
                try writer.print("i32,\n", .{});
                continue;
            };

            // Check if it's actually an integer (no decimal point)
            const has_decimal = std.mem.indexOfScalar(u8, val, '.') != null;
            if (!has_decimal) {
                try writer.print("i32,\n", .{});
            } else {
                try writer.print("f32,\n", .{});
            }
        } else break;
    }
    try writer.print("}}\n", .{});
    try writer.flush();
}

pub fn TrainTestSplit(
    comptime Schema: type,
    comptime label: []const u8,
    allocator: std.mem.Allocator,
    df: *DataFrame(Schema),
    ratio: f32,
) !TTSplit(RemoveFeature(Schema, label), ExtractFeature(Schema, label)) {
    const LabelRemoved = RemoveFeature(Schema, label);
    const Label = ExtractFeature(Schema, label);

    var XTrain = DataFrame(LabelRemoved).init(allocator);
    var XTest = DataFrame(LabelRemoved).init(allocator);
    var YTrain = DataFrame(Label).init(allocator);
    var YTest = DataFrame(Label).init(allocator);

    var prng: std.Random.DefaultPrng = .init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    const toLabelRemoved = Transform(Schema, LabelRemoved);
    const toLabel = Transform(Schema, Label);

    for (df.values.items) |*v| {
        const random = rand.float(f32);

        if (random < ratio) {
            try XTrain.addRow(toLabelRemoved(v.*));
            try YTrain.addRow(toLabel(v.*));
        } else {
            try XTest.addRow(toLabelRemoved(v.*));
            try YTest.addRow(toLabel(v.*));
        }
    }

    // 3. Return the struct initialized with the calculated types.
    return TTSplit(LabelRemoved, Label){
        .XTrain = XTrain,
        .XTest = XTest,
        .YTrain = YTrain,
        .YTest = YTest,
    };
}

// Helper to generate the return struct type
pub fn TTSplit(comptime LabelRemoved: type, comptime Label: type) type {
    return struct {
        XTrain: DataFrame(LabelRemoved),
        XTest: DataFrame(LabelRemoved),
        YTrain: DataFrame(Label),
        YTest: DataFrame(Label),
    };
}

pub fn ExtractFeature(comptime Schema: type, name: []const u8) type {
    const info = @typeInfo(Schema);

    switch (info) {
        .@"struct" => |stt| {
            inline for (stt.fields) |field| {
                if (std.mem.eql(u8, name, field.name)) {
                    // For now, return a simple tuple
                    // This keeps DataFrame working
                    var types: [1]type = undefined;
                    types[0] = field.type;
                    return std.meta.Tuple(types[0..1]);
                }
            }
        },
        else => unreachable,
    }
    @compileError("Field not found");
}

pub fn RemoveFeature(comptime Schema: type, name: []const u8) type {
    const info = @typeInfo(Schema).@"struct";

    // Build the tuple type
    var fields: [info.fields.len]type = undefined;
    var count: usize = 0;

    inline for (info.fields) |field| {
        if (!std.mem.eql(u8, name, field.name)) {
            fields[count] = field.type;
            count += 1;
        }
    }

    return std.meta.Tuple(fields[0..count]);
}

pub fn Transform(comptime A: type, comptime B: type) *const fn (A) B {
    const infoA: std.builtin.Type = @typeInfo(A);
    const infoB: std.builtin.Type = @typeInfo(B);

    if (infoA != .@"struct" or infoB != .@"struct") @compileError("Both A and B must be structs");

    // Check if B is a tuple (has numeric field names)
    const isTupleB = infoB.@"struct".fields.len > 0 and infoB.@"struct".fields[0].name[0] >= '0' and infoB.@"struct".fields[0].name[0] <= '9';

    return struct {
        fn transform(a: A) B {
            var result: B = undefined;

            if (isTupleB) {
                // When B is a tuple, copy fields from A in order
                // Assuming B has the same types in the same order as A (just with some fields removed)
                comptime var destIdx: usize = 0;
                inline for (infoA.@"struct".fields) |srcField| {
                    if (destIdx < infoB.@"struct".fields.len) {
                        const destField = infoB.@"struct".fields[destIdx];
                        if (srcField.type == destField.type) {
                            result[destIdx] = @field(a, srcField.name);
                            destIdx += 1;
                        }
                    }
                }
            } else {
                // When B has named fields, copy by field name
                inline for (infoA.@"struct".fields) |f| {
                    if (@hasField(B, f.name) and @hasField(A, f.name)) {
                        @field(result, f.name) = @field(a, f.name);
                    }
                }
            }
            return result;
        }
    }.transform;
}
