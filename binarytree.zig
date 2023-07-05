const std = @import("std");
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
var allocator: std.mem.Allocator = undefined;

const Queue = struct {
    const QueueNode = struct {
        prev: ?*QueueNode,
        next: ?*QueueNode,
        value: *Node,
    };
    head: ?*QueueNode = null,
    tail: ?*QueueNode = null,
    size: usize = 0,

    fn push(self: *Queue, node: *Node) void {
        if (self.head != null) {
            const newQueueNode: ?*QueueNode = createQueueNode();
            if (newQueueNode) |n| {
                n.prev = null;
                n.next = null;
                n.value = node;
                self.tail = n;
            }
        } else {
            const newQueueNode: ?*QueueNode = createQueueNode();
            if (newQueueNode) |n| {
                n.prev = self.tail;
                n.next = null;
                n.value = node;
                self.head = n;
                self.tail = n;
            }
        }
        self.size += 1;
    }

    fn pop(self: *Queue) ?*Node {
        const node = self.head.?.value;
        self.head = self.head.?.next;
        self.size -= 1;
        return node;
    }
};

fn createQueueNode() ?*Queue.QueueNode {
    return allocator.create(Queue.QueueNode) catch |err| {
        std.debug.print("Error creating queuenode: {}", .{err});
        return null;
    };
}

const Node = struct {
    left: ?*Node = null,
    right: ?*Node = null,
    value: u8,
};

fn insert(node: *Node, value: u8) void {
    var queue = Queue{};
    var temp: ?*Node = node;
    queue.push(temp.?);
    while (queue.size > 0) {
        temp = queue.pop();
        if (temp.?.left == null) {
            temp.?.left = newNode(value);
            break;
        } else if (temp.?.left) |left| {
            queue.push(left);
        }

        if (temp.?.right == null) {
            temp.?.right = newNode(value);
            break;
        } else if (temp.?.right) |right| {
            queue.push(right);
        }
    }
}

fn newNode(value: u8) ?*Node {
    const new_node = allocator.create(Node) catch {
        std.debug.print("Erorr trying to insert value: {}", .{value});
        return null;
    };

    new_node.right = null;
    new_node.left = null;
    new_node.value = value;
    return new_node;
}

fn inorder(temp: ?*Node) void {
    if (temp != null) {
        inorder(temp.?.left);
        std.debug.print("{} ", .{temp.?.*.value});
        inorder(temp.?.right);
    }
}

pub fn main() !void {
    var general_purpose_allocator = GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    allocator = arena_instance.allocator();

    var node = Node{
        .value = 10,
    };

    node.left = newNode(11);
    node.left.?.left = newNode(7);
    node.right = newNode(9);
    node.right.?.left = newNode(15);
    node.right.?.right = newNode(8);
    std.debug.print("Inorder traversal before insertion: ", .{});
    inorder(&node);
    insert(&node, 12);
    std.debug.print("\nInorder traversal after insertion: ", .{});
    inorder(&node);
}
