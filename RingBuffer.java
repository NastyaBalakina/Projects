/*************************************************************************
* Author: Balakina Anastasia
*
* Compilation: javac RingBuffer.java
* Execution: java RingBuffer
* Dependencies none

* The Class RingBuffer models the ring buffer
*
*  RingBuffer(int capacity)  // create an empty ring buffer, with given max capacity
*     int size()             // return number of items currently in the buffer
* boolean isEmpty()          // is the buffer empty (size equals zero)?
* boolean isFull()           // is the buffer full  (size equals capacity)?
*    void enqueue(double x)  // add item x to the end
*  double dequeue()          // delete and return item from the front
*  double peek()             // return (but do not delete) item from the front
*  String toString()         // return buffer converted to string in the same order as if 
*                            // it was returned by dequeue method
*************************************************************************/
public class RingBuffer{
	private final int capacity;
	private double[] items;
	
	private int first = 0; // stores the index of the least recently inserted item
	private int last = 0;  // stores the index one beyond the most recently inserted item
	private int size = 0;
	
	// create an empty ring buffer, with given max capacity
	public RingBuffer(int N){
		capacity = N;
		items = new double[capacity];
	}
	
	// return number of items currently in the buffer
	public int size(){
		return size;
	}
	
	// is the buffer empty (size equals zero)?
	public boolean isEmpty(){
		if (size == 0)
			return true;
		else return false;
	}
	
	//is the buffer full  (size equals capacity)?
	public boolean isFull(){
		if (size == capacity)
			return true;
		else return false;
	}
	
	// add item x to the end or if impossible throw RuntimeException
	public void enqueue(double x){
		if (size == capacity)
			throw new RuntimeException("Enqueue: buffer full"); 
		
		items[last % capacity] = x;
		last++;
		size++;
	}
	
	// delete and return item from the front or  if impossible throw RuntimeException
	public double dequeue(){
		if (size == 0)
			throw new RuntimeException("Dequeue: empty buffer");
		
		first++;
		size--;	
		return items[(first - 1) % capacity];
	}
	
	// return (but do not delete) item from the front or if impossible throw RuntimeException
	public double peek(){
		if (size == 0)
			throw new RuntimeException("Peek: empty buffer");
		
		return items[first % capacity];
	}
	
	/* return buffer converted to string in the same 
	order as if it was returned by dequeue method */
	public String toString(){
		// duplicate first and size variables
		int first1 = first;
		int size1 = size;
		
		String str = "[";
		while(size1 != 0){
			//converts item from double to string and adds it to resulting  string
			str = str + Double.toString(items[(first1) % capacity]); 
			if (size1 != 1)
				str = str + ", ";
			first1++;
			size1--;
		}
		str = str + "]";
		return str;
	}
	
	
	public static void main(String[] args){
	}
}
		