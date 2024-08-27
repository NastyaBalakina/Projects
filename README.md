# Projects
/*************************************************************************
* File name: RingBuffer.java
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
