const std = @import("std");
const iguanas = @import("iguanas");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var df = try iguanas.parseCsv(allocator, "src/test.csv", &[_]iguanas.Dtype{ .string, .int, .string });
    df.print(null);

    const mateo_name = try allocator.dupe(u8, "Mateo");
    const bogota = try allocator.dupe(u8, "Bogota");
    try df.addRow(&[_]iguanas.Value{
        iguanas.stringValue(mateo_name),
        iguanas.intValue(18),
        iguanas.stringValue(bogota),
    });

    df.print(null);

    df.deinit();
    const leak = gpa.deinit();
    std.debug.print("Leaked: {b}", .{leak});
}
