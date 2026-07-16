/*
Program : CO2070 Assembler
Author  : Isuru Nawinne
Date    : 14-April-2020

Description:
Extended to support Lab 4.5 Bonus Instructions: bne, sll, srl, sra, ror, mult.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define LINE_SIZE 512

int main(int argc, char *argv[])
{

    /* OP-CODE DEIFINITIONS
    Change these according to op-codes assigned in your processor architecture
    *************************************************************************/
    char *op_loadi = "00000000"; // 0
    char *op_mov   = "00000001"; // 1
    char *op_add   = "00000010"; // 2
    char *op_sub   = "00000011"; // 3
    char *op_and   = "00000100"; // 4
    char *op_or    = "00000101"; // 5
    char *op_j     = "00000110"; // 6
    char *op_beq   = "00000111"; // 7
    
    // --- LAB 4.5 BONUS OPCODES ---
    char *op_bne   = "00001000"; // 8
    char *op_sll   = "00001001"; // 9
    char *op_srl   = "00001010"; // 10
    char *op_sra   = "00001011"; // 11
    char *op_ror   = "00001100"; // 12
    char *op_mult  = "00001101"; // 13

    // Pushed memory instructions down to avoid conflicts
    char *op_lwd   = "00001110"; // 14
    char *op_lwi   = "00001111"; // 15
    char *op_swd   = "00010000"; // 16
    char *op_swi   = "00010001"; // 17
    /************************************************************************/

    const char delim[] = " ";
    FILE *fi, *fo;
    char line[LINE_SIZE];
    long line_count = 0;
    char *in_token;
    char out_token[] = "00000000";
    char out_file[256];

    strcpy(out_file, argv[1]);
    strcat(out_file, ".machine");

    if ((fi = fopen(argv[1], "r")) == NULL)
    {
        printf("Err0r: Cannot open source file!\n");
        exit(1);
    }

    if ((fo = fopen(out_file, "wb")) == NULL)
    {
        printf("Error: Cannot open output file!\n");
        fclose(fi);
        exit(1);
    }

    while (fgets(line, LINE_SIZE, fi) != NULL) // Read a line from the input .s file
    {
        /* Preprocess the line and insert "X" for ignored fields where needed
        *************************************************************************/
        char pline[LINE_SIZE] = "";
        char tline[LINE_SIZE];
        strcpy(tline, line);
        in_token = strtok(tline, delim); // Read the first token 

        if (strcasecmp(in_token, "mov") == 0 || strcasecmp(in_token, "loadi") == 0 || strcasecmp(in_token, "lwd") == 0 || strcasecmp(in_token, "lwi") == 0 ||
            strcasecmp(in_token, "swd") == 0 || strcasecmp(in_token, "swi") == 0 || strcasecmp(in_token, "j") == 0)
        {
            int j = (strcasecmp(in_token, "j") == 0) ? 1 : 0;                                           
            int store = (strcasecmp(in_token, "swd") == 0 || strcasecmp(in_token, "swi") == 0) ? 1 : 0; 

            strcat(pline, in_token);
            strcat(pline, delim); 

            if (store) 
            {
                strcat(pline, "X "); 
                in_token = strtok(NULL, delim); 
                strcat(pline, in_token);
                strcat(pline, delim); 
            }
            else 
            {
                in_token = strtok(NULL, delim); 
                strcat(pline, in_token);
                strcat(pline, delim); 
                strcat(pline, "X "); 
            }

            if (j)                  
                strcat(pline, "X"); 
            else                    
            {
                in_token = strtok(NULL, delim); 
                strcat(pline, in_token);        
            }
            while (1)
            {
                in_token = strtok(NULL, delim); 
                if (in_token != NULL)
                {
                    strcat(pline, delim);
                    strcat(pline, in_token); 
                }
                else
                    break;
            }
            strcat(pline, "");
        }
        else // The line is either not an instruction, or an instruction with all four tokens
            strcpy(pline, line);

        /* Encode the pre-processed line of assembly code into machine code
        *******************************************************************/
        in_token = strtok(pline, delim);
        line_count++;
        int count = 0;
        while (in_token != NULL)
        {
            count++;

            // Encoding the op-code
            if (strcasecmp(in_token, "loadi") == 0) strcpy(out_token, op_loadi);
            else if (strcasecmp(in_token, "mov") == 0) strcpy(out_token, op_mov);
            else if (strcasecmp(in_token, "add") == 0) strcpy(out_token, op_add);
            else if (strcasecmp(in_token, "sub") == 0) strcpy(out_token, op_sub);
            else if (strcasecmp(in_token, "and") == 0) strcpy(out_token, op_and);
            else if (strcasecmp(in_token, "or") == 0) strcpy(out_token, op_or);
            else if (strcasecmp(in_token, "j") == 0) strcpy(out_token, op_j);
            else if (strcasecmp(in_token, "beq") == 0) strcpy(out_token, op_beq);
            else if (strcasecmp(in_token, "lwd") == 0) strcpy(out_token, op_lwd);
            else if (strcasecmp(in_token, "lwi") == 0) strcpy(out_token, op_lwi);
            else if (strcasecmp(in_token, "swd") == 0) strcpy(out_token, op_swd);
            else if (strcasecmp(in_token, "swi") == 0) strcpy(out_token, op_swi);
            
            // --- LAB 4.5 BONUS INSTRUCTIONS ---
            else if (strcasecmp(in_token, "bne") == 0)  strcpy(out_token, op_bne);
            else if (strcasecmp(in_token, "sll") == 0)  strcpy(out_token, op_sll);
            else if (strcasecmp(in_token, "srl") == 0)  strcpy(out_token, op_srl);
            else if (strcasecmp(in_token, "sra") == 0)  strcpy(out_token, op_sra);
            else if (strcasecmp(in_token, "ror") == 0)  strcpy(out_token, op_ror);
            else if (strcasecmp(in_token, "mult") == 0) strcpy(out_token, op_mult);

            // Encoding register numbers
            else if (strcmp(in_token, "0") == 0 || strcmp(in_token, "0\n") == 0) strcpy(out_token, "00000000");
            else if (strcmp(in_token, "1") == 0 || strcmp(in_token, "1\n") == 0) strcpy(out_token, "00000001");
            else if (strcmp(in_token, "2") == 0 || strcmp(in_token, "2\n") == 0) strcpy(out_token, "00000010");
            else if (strcmp(in_token, "3") == 0 || strcmp(in_token, "3\n") == 0) strcpy(out_token, "00000011");
            else if (strcmp(in_token, "4") == 0 || strcmp(in_token, "4\n") == 0) strcpy(out_token, "00000100");
            else if (strcmp(in_token, "5") == 0 || strcmp(in_token, "5\n") == 0) strcpy(out_token, "00000101");
            else if (strcmp(in_token, "6") == 0 || strcmp(in_token, "6\n") == 0) strcpy(out_token, "00000110");
            else if (strcmp(in_token, "7") == 0 || strcmp(in_token, "7\n") == 0) strcpy(out_token, "00000111");

            // Encoding ignored operands
            else if (strcasecmp(in_token, "X") == 0) strcpy(out_token, "00000000");

            // Encoding immediate values (must be in hex format)
            else if (strstr(in_token, "0x") && (strstr(in_token, "0x") == in_token))
            {
                int i;
                for (i = 0; i < 2; i++)
                {
                    if (toupper(in_token[2 + i]) == '0') strcpy(out_token + (4 * i), "0000");
                    if (toupper(in_token[2 + i]) == '1') strcpy(out_token + (4 * i), "0001");
                    if (toupper(in_token[2 + i]) == '2') strcpy(out_token + (4 * i), "0010");
                    if (toupper(in_token[2 + i]) == '3') strcpy(out_token + (4 * i), "0011");
                    if (toupper(in_token[2 + i]) == '4') strcpy(out_token + (4 * i), "0100");
                    if (toupper(in_token[2 + i]) == '5') strcpy(out_token + (4 * i), "0101");
                    if (toupper(in_token[2 + i]) == '6') strcpy(out_token + (4 * i), "0110");
                    if (toupper(in_token[2 + i]) == '7') strcpy(out_token + (4 * i), "0111");
                    if (toupper(in_token[2 + i]) == '8') strcpy(out_token + (4 * i), "1000");
                    if (toupper(in_token[2 + i]) == '9') strcpy(out_token + (4 * i), "1001");
                    if (toupper(in_token[2 + i]) == 'A') strcpy(out_token + (4 * i), "1010");
                    if (toupper(in_token[2 + i]) == 'B') strcpy(out_token + (4 * i), "1011");
                    if (toupper(in_token[2 + i]) == 'C') strcpy(out_token + (4 * i), "1100");
                    if (toupper(in_token[2 + i]) == 'D') strcpy(out_token + (4 * i), "1101");
                    if (toupper(in_token[2 + i]) == 'E') strcpy(out_token + (4 * i), "1110");
                    if (toupper(in_token[2 + i]) == 'F') strcpy(out_token + (4 * i), "1111");
                }
            }

            // Handling comments and empty lines
            else if (strcmp(in_token, "\n") == 0 || (strstr(in_token, "//") && (strstr(in_token, "//") == in_token)))
            {
                count--;
                break;
            }
            // Handling lines/words which are not part of an instruction
            else
            {
                count = 99;
                break;
            }

            fputs(out_token, fo);
            in_token = strtok(NULL, delim);
        }

        if (count == 4) // Line contains a valid instruction
            fputs("\n", fo);
        else if (count != 0) // Line is neither a valid instruction, nor a valid comment / empty line
        {
            printf("Error: Incorrect instruction format! (line: %li)\n", line_count);
            fclose(fi);
            fclose(fo);
            exit(1);
        }
    }

    fclose(fi);
    fclose(fo);

    return 0;
}