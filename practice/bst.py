class Node(object):
    def __init__(self, value):
        self.value = value
        self.left = None
        self.right = None

class BST(object):
    def __init__(self, root):
        self.root = Node(root)

    def insert(self, new_val):
        self.bi_insert(self.root, new_val)

    def search(self, find_val):
        return self.bi_search(self.root, find_val)
    
    def bi_search(self, start, find_val):
        if start.value == find_val:
            return True
        if (start.left!=None) & (start.value > find_val):
            return self.bi_search(start.left, find_val)
        if (start.right!=None) & (start.value < find_val):
            return self.bi_search(start.right, find_val)
        return False
        
    def bi_insert(self, start, new_val):
        if start.value > new_val:
            if start.left:
                self.bi_insert(start.left, new_val)
            else:
                start.left = Node(new_val)
        if start.value < new_val:
            if start.right:
                self.bi_insert(start.right, new_val)
            else:
                start.right = Node(new_val)
    
# Set up tree
tree = BST(4)

# Insert elements
tree.insert(2)
tree.insert(1)
tree.insert(3)
tree.insert(5)

# Check search
# Should be True
print tree.search(4)
# Should be False
print tree.search(6)