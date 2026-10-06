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
        nodes: std.ArrayList(NodeData(V)),
        edges: std.ArrayList(EdgeData(E)),

        const Error = error{
            OutOfMemory,
            InvalidNode,
        };

        pub fn init() Graph(V, E) {
            return .{
                .nodes = .empty,
                .edges = .empty,
            };
        }

        pub fn deinit(self: *Graph(V, E), gpa: Allocator) void {
            self.nodes.deinit(gpa);
            self.edges.deinit(gpa);
        }

        pub fn addNode(self: *Graph(V, E), gpa: Allocator, payload: V) Error!NodeHandle {
            const index = self.nodes.items.len;
            try self.nodes.append(gpa, .{
                .payload = payload,
                .first_outgoing_edge = null,
            });
            return @enumFromInt(index);
        }

        pub fn addEdge(self: *Graph(V, E), gpa: Allocator, source_node_handle: NodeHandle, target_node_handle: NodeHandle, payload: E) Error!EdgeHandle {
            const index = self.edges.items.len;
            const source_node = self.getNode(source_node_handle) orelse return Error.InvalidNode;
            const target_node = self.getNode(target_node_handle) orelse return Error.InvalidNode;
            _ = target_node;
            try self.edges.append(gpa, .{
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

        // maybe handle.successors(graph)? idk i think graph as the authority makes more sense
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

test "colouring books r neat" {
    const Colour = enum { red, blue, green };
    const colouring = struct {
        pub fn colour(comptime C: type, graph: *Graph(?C, void)) bool {
            return colourFrom(C, graph, graph.allNodes());
        }

        fn colourFrom(comptime C: type, graph: *Graph(?C, void), remaining: anytype) bool {
            // try all colours for the next node in remaining
            var rest = remaining;
            const handle: NodeHandle = rest.next() orelse return true;
            const node = graph.getNode(handle).?;
            // for each colour...
            for (std.enums.values(C)) |c| {
                // if we find a colour we can use...
                if (!canUse(C, graph, handle, c)) continue;
                // claim it!
                node.payload = c;
                // then try to colour the rest...
                // - if we manage to colour the rest successfully given our above claim, we report success
                if (colourFrom(C, graph, rest)) return true;
                // didnt manage to colour the rest of the graph, try the next colour...
            }
            // we didnt find any working combination this attempt, so we should reset
            node.payload = null;
            return false;
        }

        fn canUse(comptime C: type, graph: *const Graph(?C, void), handle: NodeHandle, c: C) bool {
            // we can use a colour if no connected nodes share the same colour
            var iter = graph.successors(handle);
            while (iter.next()) |n| {
                if (graph.getNode(n).?.payload == c) return false;
            }
            return true;
        }
    };

    const gpa = std.testing.allocator;
    var graph: Graph(?Colour, void) = .init();
    defer graph.deinit(gpa);
    const a = try graph.addNode(gpa, null);
    const b = try graph.addNode(gpa, null);
    const c = try graph.addNode(gpa, null);
    // bidirectional triangle
    _ = try graph.addEdge(gpa, a, b, {});
    _ = try graph.addEdge(gpa, a, c, {});
    _ = try graph.addEdge(gpa, b, a, {});
    _ = try graph.addEdge(gpa, b, c, {});
    _ = try graph.addEdge(gpa, c, b, {});
    _ = try graph.addEdge(gpa, c, a, {});

    try std.testing.expect(colouring.colour(Colour, &graph));
    // graph is coloured now; all payloads have content

    var nodes = graph.allNodes();
    while (nodes.next()) |node| {
        // this node has a colour
        const node_colour = graph.getNode(node).?.payload.?;
        var neighbours = graph.successors(node);
        // that is different from all of its neighbours
        while (neighbours.next()) |neighbour| {
            try std.testing.expect(graph.getNode(neighbour).?.payload.? != node_colour);
        }
    }
}
