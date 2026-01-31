const std = @import("std");
const iguanas = @import("iguanas");
const String = iguanas.String;
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Schema = struct {
        name: String,
        age: usize,
        city: String,
        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try writer.print("{s}, {d}, {s}", .{ self.name.str(), self.age, self.city.str() });
        }
    };

    var df = try iguanas.DataFrame(Schema).fromCsv(allocator, "src/test.csv");
    defer df.deinit();

    for (df.values.items) |*row| {
        std.debug.print("{f}\n", .{row});
    }
    try df.addRow(.{
        .name = try .init_with_contents(allocator, "Mateo"),
        .age = 18,
        .city = try .init_with_contents(allocator, "Bogota"),
    });

    for (df.values.items) |*row| {
        std.debug.print("{f}\n", .{row});
    }
    const NewSchema = struct {
        nameCity: String,

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try writer.print("{s}", .{self.nameCity.str()});
        }
    };

    const transform = struct {
        fn new(alloc: ?std.mem.Allocator, row: Schema) ?NewSchema {
            const formatted = std.fmt.allocPrint(alloc.?, "{s}:{s}", .{ row.name.str(), row.city.str() }) catch return null;
            return NewSchema{ .nameCity = String{ .allocator = alloc.?, .buffer = formatted, .size = formatted.len } };
        }
    }.new;
    var newDf = try iguanas.DataFrame(NewSchema).fromDf(allocator, Schema, df, transform);
    defer newDf.deinit();

    for (newDf.values.items) |*row| {
        std.debug.print("{f}\n", .{row});
    }
}
