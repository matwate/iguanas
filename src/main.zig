const std = @import("std");
const iguanas = @import("iguanas");
const String = iguanas.String;

pub fn main() !void {
    //try iguanas.inferSchema("./src/KNNAlgorithmDataset.csv");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    const allocator = arena.allocator();
    var df = try iguanas.DataFrame(Schema).fromCsv(allocator, "./src/KNNAlgorithmDataset.csv", true);

    const ttsplit = try iguanas.TrainTestSplit(Schema, "diagnosis", allocator, &df, 0.75);
}

const Schema = struct {
    id: i32,
    diagnosis: []const u8,
    radius_mean: f32,
    texture_mean: f32,
    perimeter_mean: f32,
    area_mean: f32,
    smoothness_mean: f32,
    compactness_mean: f32,
    concavity_mean: f32,
    concave_points_mean: f32,
    symmetry_mean: f32,
    fractal_dimension_mean: f32,
    radius_se: f32,
    texture_se: f32,
    perimeter_se: f32,
    area_se: f32,
    smoothness_se: f32,
    compactness_se: f32,
    concavity_se: f32,
    concave_points_se: f32,
    symmetry_se: f32,
    fractal_dimension_se: f32,
    radius_worst: f32,
    texture_worst: f32,
    perimeter_worst: f32,
    area_worst: f32,
    smoothness_worst: f32,
    compactness_worst: f32,
    concavity_worst: f32,
    concave_points_worst: f32,
    symmetry_worst: f32,
    fractal_dimension_worst: f32,
};
