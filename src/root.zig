const std = @import("std");
const Allocator = std.mem.Allocator;

// nonexhaustive enum cannot be built using struct literal syntax
pub const NodeHandle = enum(usize) { _ };

pub fn NodeData(comptime T: type) type {
    return struct {
        payload: T,
        first_outgoing_edge: ?EdgeHandle,
    };
}

// sameshit
pub const EdgeHandle = enum(usize) { _ };

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

        const Error = error{
            OutOfMemory,
            InvalidNode,
        };

        // todo accept gpa as argument?
        pub fn init(gpa: Allocator) Graph(V, E) {
            return .{
                .gpa = gpa,
                .nodes = .empty,
                .edges = .empty,
            };
        }

        pub fn deinit(self: *Graph(V, E)) void {
            self.nodes.deinit(self.gpa);
            self.edges.deinit(self.gpa);
        }

        pub fn addNode(self: *Graph(V, E), payload: V) Error!NodeHandle {
            const index = self.nodes.items.len;
            try self.nodes.append(self.gpa, .{
                .payload = payload,
                .first_outgoing_edge = null,
            });
            return @enumFromInt(index);
        }

        pub fn addEdge(self: *Graph(V, E), source_node_handle: NodeHandle, target_node_handle: NodeHandle, payload: E) Error!EdgeHandle {
            const index = self.edges.items.len;
            const source_node = self.getNode(source_node_handle) orelse return Error.InvalidNode;
            const target_node = self.getNode(target_node_handle) orelse return Error.InvalidNode;
            _ = target_node;
            try self.edges.append(self.gpa, .{
                .payload = payload,
                .target = target_node_handle,
                .next_outgoing_edge = source_node.first_outgoing_edge,
            });
            const handle: EdgeHandle = @enumFromInt(index);
            source_node.first_outgoing_edge = handle;
            return handle;
        }

        pub const SuccessorsIterator = struct {
            graph: *const Graph(V, E),
            current_edge_handle: ?EdgeHandle,

            pub fn next(self: *SuccessorsIterator) ?NodeHandle {
                const edge_handle = self.current_edge_handle orelse return null;
                const edge = self.graph.getEdge(edge_handle) orelse return null;
                self.current_edge_handle = edge.next_outgoing_edge;
                return edge.target;
            }
        };

        pub fn successors(self: *const Graph(V, E), node_handle: NodeHandle) SuccessorsIterator {
            const first_outgoing_edge =
                if (self.getNode(node_handle)) |node| node.first_outgoing_edge else null;
            return .{
                .graph = self,
                .current_edge_handle = first_outgoing_edge,
            };
        }

        pub const NodeIterator = struct {
            next_offset: usize,
            len: usize,

            pub fn next(self: *NodeIterator) ?NodeHandle {
                if (self.next_offset >= self.len) return null;
                const handle: NodeHandle = @enumFromInt(self.next_offset);
                self.next_offset += 1;
                return handle;
            }
        };

        pub fn allNodes(self: *const Graph(V, E)) NodeIterator {
            return .{
                .next_offset = 0,
                .len = self.nodes.items.len,
            };
        }

        // opaque accessors, since we might swap offset for a ptr later...
        pub fn getNode(self: *const Graph(V, E), node_handle: NodeHandle) ?*NodeData(V) {
            const offset = @intFromEnum(node_handle);
            if (offset >= self.nodes.items.len) {
                return null;
            } else {
                return &self.nodes.items[offset];
            }
        }

        pub fn getEdge(self: *const Graph(V, E), edge_handle: EdgeHandle) ?*EdgeData(E) {
            const offset = @intFromEnum(edge_handle);
            if (offset >= self.edges.items.len) {
                return null;
            } else {
                return &self.edges.items[offset];
            }
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
