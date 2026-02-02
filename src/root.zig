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
            try writer.print("\t{s} = ", .{unquoted_name});
            // Figure out if it's an int, a float or a string as a default
            _ = std.fmt.parseInt(i32, val, 10) catch {
                _ = std.fmt.parseFloat(f32, val) catch {
                    try writer.print("[]const u8,\n", .{});
                    continue;
                };
                try writer.print("f32,\n", .{});
                continue;
            };
            try writer.print("i32,\n", .{});
        } else break;
    }

    try writer.print("}}\n", .{});
    try writer.flush();
}

pub fn TrainTestSplit(comptime Schema: type, comptime LabelRemoved: type, comptime Label: type, removeLabel: *const fn (Schema) LabelRemoved, extractLabel: *const fn (Schema) Label, allocator: std.mem.Allocator, df: *DataFrame(Schema), ratio: f32) !TTSplit(Schema) {
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

    for (df.values.items) |*v| {
        const random = rand.float(f32);

        if (random < ratio) {
            const removed = removeLabel(v.*);
            const label = extractLabel(v.*);

            try XTrain.addRow(removed);
            try YTrain.addRow(label);
        } else {
            const removed = removeLabel(v.*);
            const label = extractLabel(v.*);

            try XTest.addRow(removed);
            try YTest.addRow(label);
        }
    }

    return TTSplit(LabelRemoved, Label){
        .XTrain = XTrain,
        .XTest = XTest,
        .YTrain = YTrain,
        .YTest = YTest,
    };
}

pub fn TTSplit(comptime LabelRemoved: type, comptime Label: type) type {
    return struct {
        XTrain: DataFrame(LabelRemoved),
        XTest: DataFrame(LabelRemoved),
        YTrain: DataFrame(Label),
        YTest: DataFrame(Label),
    };
}
