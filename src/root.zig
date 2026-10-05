const std = @import("std");
const Allocator = std.mem.Allocator;

pub const NodeHandle = struct {
    offset: usize,
};

pub fn NodeData(comptime T: type) type {
    return struct {
        payload: T,
        first_outgoing_edge: ?EdgeHandle,
    };
}

pub const EdgeHandle = struct {
    offset: usize,
};

pub fn EdgeData(comptime T: type) type {
    return struct {
        payload: T,
        target: NodeHandle,
        next_outgoing_edge: ?EdgeHandle,
    };
}

pub fn Graph(comptime V: type, comptime E: type) type {
    return struct {
        gpa: Allocator,
        nodes: std.ArrayList(NodeData(V)),
        edges: std.ArrayList(EdgeData(E)),

        const Self = @This();

        const Error = error {
            OutOfMemory,
            InvalidNode,
        };

        // todo accept gpa as argument?
        pub fn init(gpa: Allocator) Self {
            return .{
                .gpa = gpa,
                .nodes = .empty,
                .edges = .empty,
            };
        }

        pub fn deinit(self: *Self) void {
            self.nodes.deinit(self.gpa);
            self.edges.deinit(self.gpa);
        }

        pub fn addNode(self: *Self, payload: V) Error!NodeHandle {
            const index = self.nodes.items.len;
            try self.nodes.append(self.gpa, .{
                .payload = payload,
                .first_outgoing_edge = null,
            });
            return .{
                .offset = index,
            };
        }

        pub fn addEdge(self: *Self, source_node_handle: NodeHandle, target_node_handle: NodeHandle, payload: E) Error!EdgeHandle {
            const index = self.edges.items.len;
            const source_node = self.getNode(source_node_handle) orelse return Error.InvalidNode;
            const target_node = self.getNode(target_node_handle) orelse return Error.InvalidNode;
            _ = target_node;
            try self.edges.append(self.gpa, .{
                .payload = payload,
                .target = target_node_handle,
                .next_outgoing_edge = source_node.first_outgoing_edge,
            });
            const handle = EdgeHandle{ .offset = index };
            source_node.first_outgoing_edge = handle;
            return handle;
        }

        pub fn successors(self: *const Self, node_handle: NodeHandle) SuccessorsIterator(V, E) {
            const first_outgoing_edge = 
                if (self.getNode(node_handle)) |node| node.first_outgoing_edge else null;
            return .{
                .graph = self,
                .current_edge_handle = first_outgoing_edge,
            };
        }

        // opaque accessors, since we might swap offset for a ptr later...
        pub fn getNode(self: *const Self, node_handle: NodeHandle) ?*NodeData(V) {
            if (node_handle.offset >= self.nodes.items.len) {
                return null;
            } else {
                return &self.nodes.items[node_handle.offset];
            }
        }

        pub fn getEdge(self: *const Self, edge_handle: EdgeHandle) ?*EdgeData(E) {
            if (edge_handle.offset >= self.edges.items.len) {
                return null;
            } else {
                return &self.edges.items[edge_handle.offset];
            }
        }
    };
}

pub fn SuccessorsIterator(comptime V: type, comptime E: type) type {
    return struct {
        graph: *const Graph(V, E),
        current_edge_handle: ?EdgeHandle,

        const Self = @This();

        pub fn next(self: *Self) ?NodeHandle {
            const edge_handle = self.current_edge_handle orelse return null;
            const edge = self.graph.getEdge(edge_handle) orelse return null;
            self.current_edge_handle = edge.next_outgoing_edge;
            return edge.target;
        }
    };
}

test "main" {
    const gpa = std.testing.allocator;
    var graph: Graph(void, void) = .init(gpa);
    defer graph.deinit();
    const a = try graph.addNode({});
    const b = try graph.addNode({});
    const c = try graph.addNode({});
    const d = try graph.addNode({});
    const e = try graph.addNode({});
    const f = try graph.addNode({});
    _ = try graph.addEdge(a, b, {});
    _ = try graph.addEdge(a, c, {});
    _ = try graph.addEdge(a, d, {});
    _ = try graph.addEdge(a, e, {});
    _ = try graph.addEdge(a, f, {});
    var iter = graph.successors(a);
    while (iter.next()) |child| {
        std.debug.print("{}\n", .{child});
    }
}