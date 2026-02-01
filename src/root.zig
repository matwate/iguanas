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

        pub fn fromCsv(allocator: std.mem.Allocator, path: []const u8) !Self {
            var buf: [4096]u8 = undefined;
            const file = try std.fs.cwd().openFile(path, .{});
            defer file.close();

            var huh = file.reader(&buf);
            var reader = &huh.interface;

            var df = Self.init(allocator);
            errdefer df.deinit();

            // Skip the header
            _ = try reader.takeDelimiter('\n');
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
