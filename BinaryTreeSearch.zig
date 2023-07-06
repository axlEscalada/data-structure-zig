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

    fn createQueueNode() ?*Queue.QueueNode {
        return allocator.create(Queue.QueueNode) catch |err| {
            std.debug.print("Error creating queuenode: {}", .{err});
            return null;
        };
    }
};

const Node = struct {
    left: ?*Node = null,
    right: ?*Node = null,
    value: u8,
};

fn insert(node: *Node, value: u8) void {
    var queue = Queue{};
    var temp: *Node = node;
    queue.push(temp);
    while (queue.size > 0) {
        temp = queue.pop().?;
        if (temp.left == null and value < temp.value) {
            temp.left = newNode(value);
            break;
        } else if (value < temp.value) {
            queue.push(temp.left.?);
        }

        if (temp.right == null and value > temp.value) {
            temp.right = newNode(value);
            break;
        } else if (value > temp.value) {
            queue.push(temp.right.?);
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

fn inOrderFormat(temp: ?*Node, depth: u8) void {
    if (temp) |t| {
        var nd = depth + 4;
        inOrderFormat(t.right, nd);
        for (0..depth) |_| {
            std.debug.print(" ", .{});
        }
        std.debug.print("{}< \n", .{t.*.value});
        inOrderFormat(t.left, nd);
    }
}

fn search(node: ?*Node, value: u8) ?*Node {
    if (node == null or node.?.*.value == value) return node;
    if (node.?.*.value < value) return search(node.?.*.right, value);
    if (node.?.*.value > value) return search(node.?.*.left, value);
    unreachable;
}

fn printResult(result: ?*Node) void {
    if (result) |r| {
        std.debug.print("Value is present: \n", .{});
        inOrderFormat(r, 0);
    } else std.debug.print("Value not present in tree\n", .{});
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

    node.left = newNode(7);
    node.left.?.left = newNode(3);
    node.right = newNode(15);
    node.right.?.left = newNode(13);
    node.right.?.right = newNode(17);
    std.debug.print("Inorder traversal before insertion: \n", .{});
    inOrderFormat(&node, 0);
    insert(&node, 12);
    insert(&node, 8);
    insert(&node, 4);
    insert(&node, 49);
    std.debug.print("\nInorder traversal after insertion: \n", .{});
    inOrderFormat(&node, 0);
    printResult(search(&node, 12));
    printResult(search(&node, 15));
    printResult(search(&node, 20));
}
