/*************************************************************************
* Author: Balakina Anastasia
*
* Compilation: 
* Execution: 
* Dependencies : Ringbuffer.java, GuitarSyring.java
* 
*
*  public class GuitarHero.java
*  Description:  Plays 37 notes on the chromatic scale from 110Hz to 880Hz
*                when the user types the lowercase letters keyboard arrangement 
*                imitates a piano keyboard: the "white keys" are on the qwerty 
*                and zxcv rows and the "black keys" on the 12345 and asdf rows of the keyboard
*                respectively in the standard drawing window.
******************************************************************************/
public class GuitarHero {

    public static void main(String[] args) {

        // Create 37 guitar strings, for related concerts
        double CONCERT_A = 440.0;
		String keys = "q2we4r5ty7u8i9op-[=zxdcfvgbnjmk,.;/' ";
		GuitarString[] strings = new GuitarString[37];
		for (int i = 0; i < 37; i++)
			strings[i] = new GuitarString(CONCERT_A * Math.pow(2, (i - 24.0) / 12.0));


        // the main input loop
        while (true) {

            // check if the user has typed a key, and, if so, process it
            if (StdDraw.hasNextKeyTyped()) {
 
                // the user types this character
                char key = StdDraw.nextKeyTyped();

                // pluck the corresponding string
				for (int i = 0; i < 37; i++)
					if (key == keys.charAt(i)) 
						strings[i].pluck(); 
            }

            // compute the superposition of the samples
			double sample = 0;
			for(int i = 0; i < 37; i++)
				sample = sample +  strings[i].sample();

            // send the result to standard audio
            StdAudio.play(sample);

            // advance the simulation of each guitar string by one step
			for(int i = 0; i < 37; i++)
				strings[i].tic();
        }
    }

}