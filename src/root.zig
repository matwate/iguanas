const std = @import("std");

pub const Dtype = enum { int, float, string };
pub const Value = union(Dtype) {
    int: i32,
    float: f32,
    string: []const u8,
};

pub fn intValue(v: i32) Value {
    return .{ .int = v };
}

pub fn floatValue(v: f32) Value {
    return .{ .float = v };
}

pub fn stringValue(v: []const u8) Value {
    return .{ .string = v };
}

const Column = union(enum) {
    int: std.ArrayListAligned(i32, null),
    float: std.ArrayListAligned(f32, null),
    string: std.ArrayListAligned([]const u8, null),

    fn deinit(col: *Column, allocator: std.mem.Allocator) void {
        switch (col.*) {
            .int => |*x| x.deinit(allocator),
            .float => |*x| x.deinit(allocator),
            .string => |*x| {
                for (x.items) |str| {
                    allocator.free(str);
                }
                x.deinit(allocator);
            },
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

    pub fn deinit(self: *DataFrame) void {
        var it = self.columns.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.columns.deinit();
    }

    pub fn addRow(self: *DataFrame, values: []const Value) !void {
        var col_ptrs = try self.allocator.alloc(*Column, self.columns.count());
        defer self.allocator.free(col_ptrs);

        {
            var it = self.columns.iterator();
            var i: usize = 0;
            while (it.next()) |entry| : (i += 1) {
                col_ptrs[i] = entry.value_ptr;
            }
        }

        for (values, 0..) |val, i| {
            try col_ptrs[i].append(self.allocator, val);
        }
    }

    pub fn print(self: *DataFrame, rows: ?usize) void {
        var it = self.columns.iterator();
        const first_col = it.next().?.value_ptr.*;
        var row_count = switch (first_col) {
            .int => |x| x.items.len,
            .float => |x| x.items.len,
            .string => |x| x.items.len,
        };

        if (rows) |rownum| {
            row_count = rownum;
        }

        for (0..row_count) |row_idx| {
            var col_it = self.columns.iterator();
            var col_idx: usize = 0;
            while (col_it.next()) |entry| : (col_idx += 1) {
                if (col_idx > 0) std.debug.print(", ", .{});
                switch (entry.value_ptr.*) {
                    .int => |x| std.debug.print("{}", .{x.items[row_idx]}),
                    .float => |x| std.debug.print("{}", .{x.items[row_idx]}),
                    .string => |x| std.debug.print("{s}", .{x.items[row_idx]}),
                }
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("\n", .{});
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
        var col: Column = undefined;
        switch (types[col_idx]) {
            .int => col = .{ .int = .{ .items = &[_]i32{}, .capacity = 0 } },
            .float => col = .{ .float = .{ .items = &[_]f32{}, .capacity = 0 } },
            .string => col = .{ .string = .{ .items = &[_][]const u8{}, .capacity = 0 } },
        }
        try df.columns.put(header, col);
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
