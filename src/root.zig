const std = @import("std");

pub const Dtype = enum { int, float, string };
const Value = union(Dtype) {
    int: i32,
    float: f32,
    string: []const u8,
};

const Column = union(enum) {
    int: std.ArrayList(i32),
    float: std.ArrayList(f32),
    string: std.ArrayList([]const u8),

    fn deinit(col: *Column) void {
        switch (col.*) {
            .int => |*x| x.deinit(),
            .float => |*x| x.deinit(),
            .string => |*x| x.deinit(),
        }
    }

    fn append(col: *Column, allocator: std.mem.Allocator, value: Value) !void {
        switch (col.*) {
            .int => |*x| try x.append(allocator, value.int),
            .float => |*x| try x.append(allocator, value.float),
            .string => |*x| try x.append(allocator, value.string),
        }
    }
};

const DataFrame = struct {
    columns: std.StringArrayHashMap(Column),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) DataFrame {
        return .{
            .columns = std.StringArrayHashMap(Column).init(allocator),
            .allocator = allocator,
        };
    }

    fn deinit(self: *DataFrame) void {
        var it = self.columns.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.columns.deinit();
    }
};

pub fn parseCsv(allocator: std.mem.Allocator, path: []const u8, types: []const Dtype) !DataFrame {
    var buf: [4096]u8 = undefined;
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var huh = file.reader(&buf);
    var reader = &huh.interface;

    const headers = (try reader.takeDelimiter('\n')).?;
    var df = DataFrame.init(allocator);

    var header_it = std.mem.tokenizeSequence(u8, headers, ",");
    var col_idx: usize = 0;
    while (header_it.next()) |header| {
        try df.columns.put(header, switch (types[col_idx]) {
            .int => Column{ .int = std.ArrayList(i32){} },
            .float => Column{ .float = std.ArrayList(f32){} },
            .string => Column{ .string = std.ArrayList([]const u8){} },
        });
        col_idx += 1;
    }

    var col_ptrs = try allocator.alloc(*Column, df.columns.count());
    defer allocator.free(col_ptrs);

    {
        var it = df.columns.iterator();
        var i: usize = 0;
        while (it.next()) |entry| : (i += 1) {
            col_ptrs[i] = entry.value_ptr;
        }
    }

    while (try reader.takeDelimiter('\n')) |line| {
        var row_it = std.mem.tokenizeSequence(u8, line, ",");
        col_idx = 0;
        while (row_it.next()) |token| {
            const value: Value = switch (types[col_idx]) {
                .int => Value{ .int = try std.fmt.parseInt(i32, token, 10) },
                .float => Value{ .float = try std.fmt.parseFloat(f32, token) },
                .string => Value{ .string = try allocator.dupe(u8, token) },
            };

            try col_ptrs[col_idx].append(allocator, value);
            col_idx += 1;
        }
    }

    std.debug.print("Column names: [", .{});
    var it = df.columns.iterator();
    while (it.next()) |entry| {
        std.debug.print("{s} ", .{entry.key_ptr.*});
    }

    std.debug.print("]\n", .{});

    return df;
}
