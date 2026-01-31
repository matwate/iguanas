const std = @import("std");
const iguanas = @import("iguanas");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const values = try iguanas.parseCsv(allocator, "src/test.csv");
    const slice = values.slice();
    const names = slice.items(.name);
    const ages = slice.items(.age);
    const cities = slice.items(.city);

    for (names, ages, cities) |n, a, c| {
        std.debug.print("{s} {d} {s}\n", .{ n, a, c });
    }
}
