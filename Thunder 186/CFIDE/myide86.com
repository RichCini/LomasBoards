�g�
�43>+|��++���f+"B++��+z|�����F �L�p
��	�� �t�|�_
� L�!�	�� ��t	�	���F
� �� t���8
�׽��F 	�u���&
�Ž��F ��|�F   �~�F   ���Ȏ؎�����	���F �u�������	����	���F �u�������	���	�p��	�9�	�
� <u�M�<Ar�<Z�,A��
���	.���닻�	냰 ���F �4ð���s1�Hö����s�f� ���f�]�T	���
�O �_	���C	����> �N	���2	����- �=	���!	���1 ���	���% ���		��� �	1�ÊN�'	�N �!	EE��u�ÊF���F ��ÌȎؽ��F ��t��û9�����F �uý��F ����j���ÌȎػ����<Yt�ý��F ��t�û9�v���F �uý��F ���j�Z�ÌȎػ\�L��r���WÌȎؽ��F �ЈF ���uû��$���uûm�ÌȎ��(s�����<�/�����F ��.� �F ���>���t�����3<u��~���F �t���F ���t������<u��At�ÌȎػ���K���F ���F ����}��&���F ���F �P���F ���F ���F �ȈF u���tƻ��CÌȎػ��8�<Yt�Dû-�'�����F ���F ���������F ���F �2���F ���F ���F �ȈF u��~tƻ���ÌȎؽ��F �u���������<Ytø  �|�F �~�F ���������F ���t�������|�F 	�u��t����`�<u� ������F ���t����B��Ȏػ��6�<Yt�p�|�  �F �~�  �F �.�+� ������F �����v�����F ��&t����������|�F 	�u���t������<u� �1����F ��Nu땻2���Ȏػ���|�  �F �~�  �F ��� �������F ��U���������F ��B����� 6�6:uGF���>�D�=�;�/�4��� 6��F���8� �>���� 6���G�����|�F 	�u�%�Et�E�����C<u��~u�Y��V��� �G����F ÌȎظ  ��� �F EE�����ö��6�s����s����� L�!����:�|�F ��+�q�(�~�F �{�K�_���F 0��û��K��F �%M�F ����5�}�F �M�F �����w�F ��M�F ���t�F ����� û�����F ��M�F �������|�F �����û�����F ��~�F ����������v ��� ��G� ���6��v�~�F��u� ��6�$< s�.<~s����G��u���u��wý|�F @�F ��<u�  �F �~�F @= t	�F ��1��1�Hý|�F �� tH�F ��< �F �~�F �� u
H�F �1�ûM� 1�H����p��$u-�$�t����l$@u�0���`$ u�Z���T�z���L�	�8��$t���8$�t����,$@t���� $t�A��$t�d�����w� �P���X����ð��3���2� ��u�0��2�2 ���������$�t�
 ��u�0�����QR������u�Iu�ZYø �Hu��� �+s��� ���=s�����F �ŵ ��2@�2�0�F E�1�F E��2��u��O��$t�����T �� s����0��H�� s�����F �ŵ ���3�F E�0�F E�1�P�2 �2X�2��u䰒�3��� ��$t�w�ý|�F @�t�F �Ʋ�� �~�F �v�F �Ʋ�� �w�f ���� �� ��
�� Ê6����Π�� �6��� �6�����������
6��� �6��� �6��� �6��
�y õ���S��Y ��$�4@t��u���u��[��[õ���S��8 ��$�<t��u���u��[��[ø  ��� �F EE���  ��� �F EE��È��2@�2�0�ƈ��20��2ð��3���0���2 �2���20��2���3ð��3���1���2 �2���20��2���3�P��� ��� X�P��� X� �QP���� X� Y�$�'@'���1 �Q.�C<$t< t��� ��Yûd����Q� � Y�Q� � Y���R�ʴ�!Z���u�P���P0���u�Xu�X���!ô�!$����$t:<,t,<t(<
t$< t <t<0r"<:r<Ar<[r<ar<{r�$_PQ����YXð����?��Q�б���B������e�Y�SQ�  ��<0r'�� r ñ��S��[<0r� r	 Èش Y[�Y[��< t<,t<t	<tY[�m��ķ ����Y[�SQ� �  �B�<0r:Q���Y�n rE ����Y[�SQ� �  ��<0rQS�� ���[���Y�C r ����< t<,t<t����Y[û0���*�Q� Q��r	�0P��X��1P��XY��Y�,0r<
�s	,<
r<��
$

Standalone IDE Test Program for T186
$

IDE HDisk Test Menu Routines.  $A=Select Drive A  B=Select Drive B  C=Boot CPM   D=Set Sec Display $On
$Off
$E=Clear Sec Buff  F=Format Disk     I=Next Sec   J=Previous Sec
L=Set LBA Value   N=Power Down      O=Disk ID    Q=LBA Display Test
R=Read Sector     S=Seq Sec Rd      U=Power Up   V=Read N Sectors
W=Write Sector    X=Write N Sectors Y=Copy A->B  Z=Verify A=B
(ESC) Back to Main Menu

Current settings:- $Enter a Command:- $
Initilizing IDE Board, one moment please...
$
Initilizing of First Drive failed. Aborting Command.

$
Initilizing of Second Drive failed. (Possibly not present).

$
First Drive ID Infornmation appears invalid. (Drive possibly not present).
Aborting Command.

$
Drive/CF Card Information:-
Model: $S/N:   $Rev:   $Cylinders: $, Heads: $, Sectors: $CPM TRK = $ CPM SEC = $  (LBA = 00$)$H$H
$
Command Not Done Yet$

Will erase data on the current drive, are you sure? (Y/N)...$Sector Read OK
$Sector Write OK
$Enter CPM style TRK & SEC values (in hex).
$Drive Error, Status Register = $Drive Error, Error Register = $Starting sector number,(xxH) = $Starting HEAD number,(xxH) = $Enter Starting Track number,(xxH) = $Track number (LOW byte, xxH) = $Track number (HIGH byte, xxH) = $Head number (01-0f) = $Number of sectors to R/W (xxH) = $Enter DMA Adress (Up to 5 digits, xxxxxH) = $
1 & 9 sectors. Only!
$
1 & 18 sectors. Only!
$Drive Busy (bit 7) stuck high.   Status = $Drive Ready (bit 6) stuck low.  Status = $Drive write fault.    Status = $Unknown error in status register.   Status = $Bad Sector ID.    Error Register = $Uncorrectable data error.  Error Register = $Error setting up to read Drive ID
$Sector not found. Error Register = $Invalid Command. Error Register = $Track Zero not found. Error Register = $Unknown Error. Error Register = $
To Abort enter ESC. Any other key to continue. $Fill disk sectors of Disk [A] with 0E5H$Fill disk sectors of Disk [B] with 0E5H$  on Drive A
$  on Drive B
$
Already on Track 0, Sector 0$
Already at start of disk!$
At end of Disk!$
Sector buffer area cleared to 0000....$
Read multiple sectors from current disk/CF card to RAM buffer.
How many 512 byte sectores (xx HEX):$
Write multiple sectors RAM buffer CURRENT disk/CF card.
How many 512 byte sectores (xx HEX):$
Read Sector to RAM buffer. $
Write Sector from RAM buffer. $
Copy CPM Partition on Drive A to Drive B (Y/N)? $
Will verify CPM Partition on Drive A to Drive B.$
Disk Copy Done.$
Verify Error. $
Disk Verify Done.$
Hit any key to continue.$ OK
$
Sector Copy Error.$   <<<<< Current Drive = [A] >>>>>

$   <<<<< Current Drive = [B] >>>>>

$
Sector Format Error$
Invalid Command (or code not yet done)
$
Address paramater error.$
Paramater range error.$RAM STORE AREA->                      �                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               �                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 