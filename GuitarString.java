/*************************************************************************
* Author: Balakina Anastasia
*
* Compilation: 
* Execution: 
* Dependencies : Ringbuffer.java
*
*  public class GuitarString
------------------------------------------------------------------------------------------------------------------------
       GuitarString(double frequency)  // create a guitar string of the given frequency, using a sampling rate of 44,100
       GuitarString(double[] init)     // create a guitar string whose size and initial values are given by the array
  void pluck()                         // set the buffer to white noise
  void tic()                           // advance the simulation one time step
double sample()                        // return the current sample
   int time()                          // return number of tics
*************************************************************************/
public class GuitarString{
	private int N; //size of the string
	private RingBuffer string1; //string
	private int time = 0; //number of ticks
	
	// create a guitar string of the given frequency, using a sampling rate of 44,100
	public GuitarString(double frequency){
		N =  (int)Math.round(44100.0 / frequency);
		 string1 = new RingBuffer(N);
		for (int i = 0; i < N; i++)
			string1.enqueue(0.0);
	}
	
	// create a guitar string whose size and initial values are given by the array
	public GuitarString(double[] init){
		N = init.length;
		 string1 = new RingBuffer(N);
		for (int i = 0; i < N; i++)
			string1.enqueue(init[i]);
	}
	
	// set the buffer to white noise
	public void pluck(){
		double a;
		int n = string1.size(); //curren size of string1
		for (int i = 0; i < n; i++){
			a = string1.dequeue();
			string1.enqueue(Math.random() - 0.5);
		}
	}
	
	// advance the simulation one time step
	public void tic() {
		double a = string1.dequeue();
		string1.enqueue(( a + string1.peek()) / 2 * 0.994);
		time++;
		}
	
	// return the current sample
	public double sample() {
		double a = string1.peek();
		return a;
	}
	
	// return number of tics
	public int time(){
		return time;
	}
}
	