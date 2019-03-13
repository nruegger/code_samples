#Implement a function recursivly to get the desired Fibonacci sequence value.

def search_fib(first, second, current, requested):
    if requested==0:
        return 0
    elif current >= requested:
        return second
    else:
        return search_fib(second, first+second, current+1, requested)
    
def get_fib(position):
    return search_fib(0, 1, 1, position)

# Test cases
print get_fib(9) #expected - 34
print get_fib(11) #expected - 89
print get_fib(0) #expected - 0