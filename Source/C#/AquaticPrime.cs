/*
	AquaticPrime.cs
	AquaticPrime Framework

	Copyright (c) 2008, Kyle Kinkade
	All rights reserved.

	Redistribution and use in source and binary forms, with or without modification,
	are permitted provided that the following conditions are met:
	•Redistributions of source code must retain the above copyright notice,
 		this list of conditions and the following disclaimer.
	•Redistributions in binary form must reproduce the above copyright notice,
		this list of conditions and the following disclaimer in the documentation and/or
		other materials provided with the distribution.
	•Neither the name of Aquatic nor the names of its contributors may be used to 
		endorse or promote products derived from this software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
   IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
   FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
   DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER 
   IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT 
   OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

using System;
using System.Xml;
using System.Text;
using System.Collections;
using System.Globalization;
using System.Security.Cryptography;
using System.Text.RegularExpressions;

namespace AquaticPrime
{
    sealed class AquaticPrime
    {
        
        private RSACryptoServiceProvider rsa;
        private string publicKey;

        /*
			*This is currently implemented as a singleton, remove both GetInstance and instance
        	*if you don't want this class as a singleton
        */
		private static readonly BGRegistrationCenter instance = new BGRegistrationCenter();
        public static BGRegistrationCenter GetInstance()
        {          
            return instance;
        }

        public bool VerifyLicenseData(XmlDocument xmlDoc)
        {
            try
            {
				//if publicKey is Hex, convert to Base64
                if(isHex(publicKey))
					publicKey = Hex2B64(publicKey);
					
                RSAParameters rsp = new RSAParameters();

				//set publicKey
                rsp.Modulus = Convert.FromBase64String(publicKey);

                //we know that the exponent is supposed to be 3
                rsp.Exponent = Convert.FromBase64String("Aw==");
              
                rsa = new RSACryptoServiceProvider();
                rsa.ImportParameters(rsp);

                SortedList dict = CreateDictionaryForLicenseData(xmlDoc);

				//retrieves Signature from SortedList, then removes it
                string signature = dict["Signature"].ToString();
                dict.Remove("Signature");

                IList values = dict.GetValueList();

				//append values together to form comparable signature
                StringBuilder dataString = new StringBuilder();
                foreach(string v in values)
                {
                    dataString.Append(v);
                }

				//create byte arrays of both signature and appended values
                byte[] signaturebytes = Convert.FromBase64String(signature);
                byte[] plainbytes = Encoding.UTF8.GetBytes(dataString.ToString());
                
				//then return whether or not license is valid
                return rsa.VerifyData(plainbytes, "SHA1", signaturebytes);
            }
            catch
            {
                return false;
            }
        }

        public static SortedList CreateDictionaryForLicenseData(XmlDocument xmlDoc)
        {
            SortedList result = new SortedList();
            XmlNode xnode = xmlDoc.LastChild.SelectSingleNode("dict");

            //return if node is null, or does not contain children, or contains an odd amount of children
            if(xnode == null || !xnode.HasChildNodes || (xnode.ChildNodes.Count % 2 != 0))
                return result;

			//iterate through the nodes, adding them as key/value pair to SortedList
            for (int i = 0; i < xnode.ChildNodes.Count; i++ )
                result.Add(xnode.ChildNodes[i].InnerText, xnode.ChildNodes[++i].InnerText);

            return result;
        }

        public static bool isHex(string sHex)
        {
            Regex r = new Regex(@"^[A-Fa-f0-9]+$");
            return r.IsMatch(sHex);
        }

        public static string Hex2B64(string sHex)
        {
            //removes the 0x from the string if it contains it
            sHex = sHex.Replace("0x", string.Empty);

            //tries to determine of the string is Hexidecimal
            if (!isHex(sHex))
                return String.Empty;

			//creates a byte array for the Hex
            byte[] bytes = new byte[sHex.Length / 2];

			//iterates through the string, parsing into bytes
            int b = 0;
            for (int i = 0; i < sHex.Length; i += 2)
            {
                bytes[b] = byte.Parse(sHex.Substring(i, 2), NumberStyles.HexNumber);
                b++;
            }
            
			//returns it as a Base64 string
            return Convert.ToBase64String(bytes);
        }

        public string PublicKey
        {
            get { return publicKey; }
            set { publicKey = value.Replace("0x", String.Empty); }
        }
    }
}