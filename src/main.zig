const std = @import("std");
const iguanas = @import("iguanas");
const String = iguanas.String;
pub fn main() !void {
    try iguanas.inferSchema("src/KNNAlgorithmDataset.csv");
}
