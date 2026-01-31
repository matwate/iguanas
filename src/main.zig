const std = @import("std");
const iguanas = @import("iguanas");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const df = try iguanas.parseCsv(allocator, "src/test.csv", &[_]iguanas.Dtype{ .string, .int, .string });

    var it = df.columns.iterator();
    const first_col = it.next().?.value_ptr.*;
    const row_count = switch (first_col) {
        .int => |x| x.items.len,
        .float => |x| x.items.len,
        .string => |x| x.items.len,
    };

    for (0..row_count) |row_idx| {
        var col_it = df.columns.iterator();
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
}
