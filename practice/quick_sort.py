#quick sort in python
#input unsorted array
#output sorted array

def quicksort(array):
    pivot=len(array)-1
    compare=0
    if pivot < 1:
        return array
    if pivot==1:
        if array[0]<array[1]:
            return array
        else:
            return [array[1],array[0]]
    while pivot>compare:
        if array[pivot]<array[compare]:
            if compare==(pivot-1):
                temp=array[compare]
                array[compare]=array[pivot]
                array[pivot]=temp
            else:
                temp=array[pivot-1]
                array[pivot-1]=array[pivot]
                array[pivot]=array[compare]
                array[compare]=temp
            pivot-=1
        else:
            compare+=1
    if pivot < 1:
        front=[array[0]]
        back=quicksort(array[1:])
        array=front+back
    elif pivot < 2:
        front=array[:2]
        back=quicksort(array[2:])
        array=front+back
    elif pivot==(len(array)-1):
        front=quicksort(array[:-1])
        back=[array[-1]]
        array=front+back
    else:
        
        front=quicksort(array[:(pivot)])
        mid=[array[(pivot)]]
        back=quicksort(array[pivot+1:])
        array=front+mid+back
    return array

#Test cases

test = [21, 4, 1, 3, 9, 20, 25, 6, 21, 14]
print quicksort(test)