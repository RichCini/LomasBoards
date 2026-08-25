import os

# ==========================================
# CP/M-86 DPB Constants (Based on dpb_ibmds)
# ==========================================
# dpb_ibmds 
#	dw	8		;SPT =8
#	db	4		;BSH =4 (2048) 3=1024
#	db	15		;BLM =15 7
#	db	1		;EXM 0
#	dw	157		;DSM blocks - 1 155
#	dw	63		;DRM dir entries - 1
#	db	80h		;AL0 C0
#	db	0		;AL1
#	dw	16		;CKS
#	dw	1		;OFF # reserved tracks
#	db	2		;PSH physical sector shift 2=512b
#	db	3		;PHM physical sector mask 3=512b
# 8 physical sectors of 512 bytes = 4096 bytes per track.
# 4096 bytes / 128 logical bytes = 32 logical sectors per track.
# There is no XLAT table.
SECTORS_PER_TRACK = 32 
SECTOR_SIZE = 128
TRACK_OFFSET = 1      # OFF = 1 (1 reserved boot track)
BLOCK_SIZE = 2048     # BSH = 4
DIRECTORY_BLOCKS = 1  # AL0 = 0x80 (First 1 block reserved for directory)
ENTRY_SIZE = 32
TRACKS_PER_SIDE = 40  # Standard for 5.25" DSDD layouts
EXM_MASK = 1          # EXM = 1 from your DPB specification
DSM = 157             # DSM = highest valid block number (blocks - 1)
TOTAL_BLOCKS = DSM + 1  # 158 total blocks, 0..DSM
DRM = 63              # DRM = highest valid directory entry index (entries - 1)
TOTAL_DIR_ENTRIES = DRM + 1  # 64 directory entries, 0..DRM
UNUSED_ENTRY = 0xE5   # marker byte for a free/deleted directory entry
BLOCKS_PER_DIR_ENTRY = 16  # 8-bit block pointers, entry[16:32]

def logical_track_to_physical_offset(logical_track):
    """
    Translates a CP/M logical track number into a byte offset using a serpentine
    (out and back) layout. 
    Side 0 (Tracks 0-39) moves outward to inward.
    Side 1 (Tracks 40-79) moves inward back to outward.
    """
    bytes_per_track = SECTORS_PER_TRACK * SECTOR_SIZE

    if logical_track < TRACKS_PER_SIDE:
        # Side 0 tracks map directly to physical cylinders 0 to 39, Head 0
        cylinder = logical_track
        head = 0
    else:
        # Side 1 tracks map in reverse: Track 40 is Cylinder 39, Track 79 is Cylinder 0
        logical_track_side_1 = logical_track - TRACKS_PER_SIDE
        cylinder = (TRACKS_PER_SIDE - 1) - logical_track_side_1
        head = 1

    # Alternating cylinder layout offset calculation:
    # Cylinder 0 Head 0, Cylinder 0 Head 1, Cylinder 1 Head 0, Cylinder 1 Head 1...
    physical_track_index = (cylinder * 2) + head
    return physical_track_index * bytes_per_track

def read_block(f, block_number):
    """
    Reads a 2048-byte data block from the disk image.
    Adjusted so block_number is 0-based relative to the start of the data area.
    """
    sectors_per_block = BLOCK_SIZE // SECTOR_SIZE
    total_logical_sectors = block_number * sectors_per_block
    
    # Track 0-based offset tracking relative to data area
    logical_track = TRACK_OFFSET + (total_logical_sectors // SECTORS_PER_TRACK)
    sector_within_track = total_logical_sectors % SECTORS_PER_TRACK
    
    # Calculate absolute position using serpentine track mechanics
    track_offset = logical_track_to_physical_offset(logical_track)
    sector_offset = sector_within_track * SECTOR_SIZE
    
    f.seek(track_offset + sector_offset)
    return f.read(BLOCK_SIZE)

def write_block(f, block_number, data):
    """
    Writes a data block (padded/truncated to exactly BLOCK_SIZE bytes) to the
    disk image at the given 0-based data-area block number, using the same
    serpentine track translation as read_block().
    """
    sectors_per_block = BLOCK_SIZE // SECTOR_SIZE
    total_logical_sectors = block_number * sectors_per_block

    logical_track = TRACK_OFFSET + (total_logical_sectors // SECTORS_PER_TRACK)
    sector_within_track = total_logical_sectors % SECTORS_PER_TRACK

    track_offset = logical_track_to_physical_offset(logical_track)
    sector_offset = sector_within_track * SECTOR_SIZE

    payload = data[:BLOCK_SIZE]
    if len(payload) < BLOCK_SIZE:
        payload = payload + b"\x00" * (BLOCK_SIZE - len(payload))

    f.seek(track_offset + sector_offset)
    f.write(payload)

def parse_entries(dir_data):
    """
    Parses CP/M-86 directory entries incorporating EX, S2, and S1 indicators.
    """
    num_entries = len(dir_data) // ENTRY_SIZE
    parsed_entries = []

    for i in range(num_entries):
        entry = dir_data[i * ENTRY_SIZE : (i + 1) * ENTRY_SIZE]
        if len(entry) < ENTRY_SIZE:
            break

        user_code = entry[0]
        if user_code == 0xE5:
            continue

        raw_name = entry[1:9]
        raw_ext = entry[9:12]

        name = "".join(chr(b & 0x7F) for b in raw_name).strip()
        ext = "".join(chr(b & 0x7F) for b in raw_ext).strip()
        filename = f"{name}.{ext}" if ext else name

        extent_low = entry[12]   # EX field
        s1_size_byte = entry[13] # S1 field (Exact terminal byte count)
        extent_high = entry[14]  # S2 field (High extent multiplier)
        record_count = entry[15] # RC field

        read_only = bool(raw_ext[0] & 0x80)
        system_file = bool(raw_ext[1] & 0x80)

        # Calculate absolute true logical extent using CP/M architectural standard rules
        # Mask off the EX bits controlled by EXM to find the base boundary entry slot
        base_extent = extent_low & (~EXM_MASK & 0xFF)
        true_extent = (extent_high * 32) + base_extent

        alloc_map = list(entry[16:32])

        parsed_entries.append({
            "index": i,
            "user": user_code,
            "filename": filename.upper(),
            "ex": extent_low,
            "s2": extent_high,
            "true_extent": true_extent,
            "s1_size": s1_size_byte,
            "records": record_count,
            "blocks": alloc_map,
            "is_ro": read_only,
            "is_sys": system_file
        })
    return parsed_entries

LOGICAL_EXTENT_SIZE = 128 * SECTOR_SIZE  # 16384 bytes - fixed by the CP/M spec,
                                          # independent of EXM/BLOCK_SIZE.


def calculate_extent_byte_size(active_block_count, records, is_last_extent, s1_size):
    """
    Computes how many bytes of real file data a single directory entry
    (one 32-byte "extent" record) actually holds.

    A directory entry only has 16 block pointers, and with BSH=4/EXM=1 those
    16 blocks (32768 bytes) span TWO 16K logical extents. The RC byte can only
    encode 0-128 records (max 16K) - it describes the record count of the
    highest/last logical-extent-group held in *this* entry only. Any logical
    extent(s) *before* that one, but still inside this same directory entry,
    are implicitly completely full (CP/M never leaves a gap).

    Critically: any directory entry that is NOT the file's last one is, by
    CP/M convention, guaranteed to be completely full - a new extent is only
    ever opened once the current one is exhausted. So RC must never be trusted
    to size an interior entry; doing so (as the original code did) silently
    truncates every non-final entry to at most 8 blocks and corrupts/derails
    everything that follows for any file spanning more than one directory
    entry (i.e. bigger than 16 blocks / 32KB).
    """
    if active_block_count == 0:
        return 0

    blocks_per_logical_extent = LOGICAL_EXTENT_SIZE // BLOCK_SIZE  # = 8 here

    if not is_last_extent:
        # Interior entry: must be fully packed - trust the allocation, not RC.
        return active_block_count * BLOCK_SIZE

    # Last entry for the file: figure out how many *whole* logical extents
    # precede the final (possibly partial) one within this same entry.
    if active_block_count <= blocks_per_logical_extent:
        full_logical_extents = 0
    else:
        full_logical_extents = (active_block_count - 1) // blocks_per_logical_extent

    full_bytes = full_logical_extents * blocks_per_logical_extent * BLOCK_SIZE
    trailing_bytes = records * SECTOR_SIZE
    total = full_bytes + trailing_bytes

    # Exact-byte trim (CP/M-86 S1 field) applies only to the very last record
    # of the very last block of the file.
    if 0 < s1_size < 128:
        total = total - SECTOR_SIZE + s1_size

    # Never claim more data than is actually allocated.
    return min(total, active_block_count * BLOCK_SIZE)


def format_cpm_filename(target_filename):
    """
    Splits/pads/validates a filename into CP/M's fixed 8.3 (name, ext) form.
    Raises ValueError if either part won't fit.
    """
    target_filename = target_filename.strip().upper()
    if "." in target_filename:
        name, ext = target_filename.split(".", 1)
    else:
        name, ext = target_filename, ""

    if len(name) > 8 or len(ext) > 3:
        raise ValueError(
            f"'{target_filename}' doesn't fit CP/M's 8.3 naming limit (name<=8, ext<=3)."
        )
    if not name:
        raise ValueError("Filename must have a non-empty name part.")

    return name.ljust(8), ext.ljust(3)

def find_free_directory_slots(entries, count_needed):
    """
    Returns up to count_needed directory entry indices not currently occupied
    by any live (non-0xE5) entry. Raises ValueError if there aren't enough.
    """
    used_indices = {e["index"] for e in entries}
    free = [i for i in range(TOTAL_DIR_ENTRIES) if i not in used_indices]
    if len(free) < count_needed:
        raise ValueError(
            f"Not enough free directory entries: need {count_needed}, have {len(free)}."
        )
    return free[:count_needed]

def find_free_blocks(entries, count_needed):
    """
    Returns up to count_needed data block numbers not referenced by any live
    directory entry (block 0 / the directory block(s) are always excluded).
    Raises ValueError if there isn't enough free space.
    """
    used_blocks = set()
    for e in entries:
        for b in e["blocks"]:
            if b != 0:
                used_blocks.add(b)

    free = [b for b in range(DIRECTORY_BLOCKS, TOTAL_BLOCKS) if b not in used_blocks]
    if len(free) < count_needed:
        raise ValueError(
            f"Not enough free space: need {count_needed} blocks "
            f"({count_needed * BLOCK_SIZE} bytes), have {len(free)} blocks free."
        )
    return free[:count_needed]

def compute_entry_ex_s2(group_index):
    """
    Inverse of the EX/S2 decode in parse_entries(): given the 0-based index of
    a directory entry *for this file* (0, 1, 2...), returns the (EX, S2) byte
    pair to write, honoring the EXM grouping (true_extent steps by EXM+1).
    """
    true_extent = group_index * (EXM_MASK + 1)
    extent_low = true_extent & 0x1F
    extent_high = (true_extent >> 5) & 0xFF
    return extent_low, extent_high

def compute_last_entry_rc_s1(last_entry_bytes, blocks_in_last_entry):
    """
    Inverse of calculate_extent_byte_size() for the file's final directory
    entry: given how many bytes of real data live in that entry and how many
    blocks it occupies, returns the (records, s1_size) fields to write so that
    a later extraction round-trips back to the exact original byte count.
    """
    blocks_per_logical_extent = LOGICAL_EXTENT_SIZE // BLOCK_SIZE  # = 8 here

    if blocks_in_last_entry <= blocks_per_logical_extent:
        full_logical_extents = 0
    else:
        full_logical_extents = (blocks_in_last_entry - 1) // blocks_per_logical_extent

    full_bytes = full_logical_extents * blocks_per_logical_extent * BLOCK_SIZE
    trailing_bytes = last_entry_bytes - full_bytes

    records = (trailing_bytes + SECTOR_SIZE - 1) // SECTOR_SIZE  # ceil
    remainder = trailing_bytes % SECTOR_SIZE
    s1_size = remainder if remainder != 0 else 0

    return records, s1_size

def build_directory_entry_bytes(user_code, name8, ext3, extent_low, extent_high,
                                 s1_size, records, blocks, read_only=False, system_file=False):
    """
    Assembles one raw 32-byte CP/M-86 directory entry.
    """
    entry = bytearray(ENTRY_SIZE)
    entry[0] = user_code
    entry[1:9] = name8.encode("ascii")

    ext_bytes = bytearray(ext3.encode("ascii"))
    if read_only:
        ext_bytes[0] |= 0x80
    if system_file:
        ext_bytes[1] |= 0x80
    entry[9:12] = ext_bytes

    entry[12] = extent_low
    entry[13] = s1_size
    entry[14] = extent_high
    entry[15] = records

    padded_blocks = list(blocks) + [0] * (BLOCKS_PER_DIR_ENTRY - len(blocks))
    entry[16:32] = bytes(padded_blocks[:BLOCKS_PER_DIR_ENTRY])

    return bytes(entry)

def write_directory_entry(f, dir_start_offset, slot_index, entry_bytes):
    f.seek(dir_start_offset + slot_index * ENTRY_SIZE)
    f.write(entry_bytes)

def delete_file(image_path, target_filename, entries):
    """
    Marks every directory entry belonging to target_filename as free (0xE5),
    freeing both the directory slots and the blocks they reference.
    """
    target_filename = target_filename.upper().strip()
    file_entries = [e for e in entries if e["filename"] == target_filename]
    if not file_entries:
        print(f"\n[!] Error: File '{target_filename}' not found.")
        return False

    dir_start_offset = logical_track_to_physical_offset(TRACK_OFFSET)
    blank = bytes([UNUSED_ENTRY]) + b"\x00" * (ENTRY_SIZE - 1)

    with open(image_path, "r+b") as f:
        for e in file_entries:
            write_directory_entry(f, dir_start_offset, e["index"], blank)

    print(f"[+] Deleted '{target_filename}' ({len(file_entries)} directory entries freed).")
    return True

def inject_file(image_path, host_file_path, entries, target_filename=None,
                 user_code=0, read_only=False, system_file=False):
    """
    Injects a host file into the CP/M-86 disk image: allocates free blocks,
    writes the file's data into them (via the same serpentine track layout
    used for reading), and writes one or more new directory entries -
    chaining as many as needed for files bigger than 16 blocks / 32KB.
    """
    if not os.path.exists(host_file_path):
        print(f"\n[!] Error: Host file '{host_file_path}' not found.")
        return False

    if target_filename is None:
        target_filename = os.path.basename(host_file_path)

    try:
        name8, ext3 = format_cpm_filename(target_filename)
    except ValueError as e:
        print(f"\n[!] Error: {e}")
        return False

    cpm_filename_display = f"{name8.strip()}.{ext3.strip()}" if ext3.strip() else name8.strip()

    if any(e["filename"] == cpm_filename_display for e in entries):
        print(f"\n[!] Error: '{cpm_filename_display}' already exists on the image. "
              f"Delete it first if you want to replace it.")
        return False

    with open(host_file_path, "rb") as hf:
        data = hf.read()

    total_size = len(data)

    # Standard CP/M convention: pad the tail of a text file's last block with
    # ^Z (0x1A) fill bytes rather than leaving whatever garbage was on disk.
    text_extensions = ["TXT", "ASM", "BAT", "SUB", "A86", "H", "C", "PAS", "DOC"]
    pad_byte = b"\x1A" if ext3.strip() in text_extensions else b"\x00"

    blocks_needed = (total_size + BLOCK_SIZE - 1) // BLOCK_SIZE if total_size > 0 else 0
    entries_needed = max(1, (blocks_needed + BLOCKS_PER_DIR_ENTRY - 1) // BLOCKS_PER_DIR_ENTRY)

    try:
        dir_slots = find_free_directory_slots(entries, entries_needed)
        assigned_blocks = find_free_blocks(entries, blocks_needed)
    except ValueError as e:
        print(f"\n[!] Error: {e}")
        return False

    dir_start_offset = logical_track_to_physical_offset(TRACK_OFFSET)

    print(f"\nInjecting '{host_file_path}' as '{cpm_filename_display}' "
          f"({total_size} bytes -> {blocks_needed} blocks, {entries_needed} directory entries)...")

    try:
        with open(image_path, "r+b") as f:
            # --- write file data blocks ---
            for i in range(blocks_needed):
                chunk = data[i * BLOCK_SIZE:(i + 1) * BLOCK_SIZE]
                if len(chunk) < BLOCK_SIZE:
                    chunk = chunk + pad_byte * (BLOCK_SIZE - len(chunk))
                write_block(f, assigned_blocks[i], chunk)

            # --- write directory entries ---
            for group_index in range(entries_needed):
                is_last = (group_index == entries_needed - 1)
                entry_blocks = assigned_blocks[group_index * BLOCKS_PER_DIR_ENTRY:
                                                (group_index + 1) * BLOCKS_PER_DIR_ENTRY]

                extent_low, extent_high = compute_entry_ex_s2(group_index)

                if is_last:
                    bytes_before_this_entry = group_index * BLOCKS_PER_DIR_ENTRY * BLOCK_SIZE
                    last_entry_bytes = total_size - bytes_before_this_entry
                    records, s1_size = compute_last_entry_rc_s1(last_entry_bytes, len(entry_blocks))
                else:
                    records, s1_size = 0x80, 0  # fully-packed interior entry

                entry_bytes = build_directory_entry_bytes(
                    user_code, name8, ext3, extent_low, extent_high,
                    s1_size, records, entry_blocks, read_only, system_file
                )
                write_directory_entry(f, dir_start_offset, dir_slots[group_index], entry_bytes)

                print(f"    dir slot {dir_slots[group_index]}: EX={extent_low} S2={extent_high} "
                      f"RC={records} S1={s1_size} blocks={entry_blocks}"
                      f"{' [final]' if is_last else ''}")

        print(f"[+] Success! '{cpm_filename_display}' injected into '{image_path}'.")
        return True

    except Exception as e:
        print(f"[!] Injection failed: {e}")
        return False

def extract_file(image_path, target_filename, entries):
    """
    Gathers all file sections, sorts them dynamically based on the calculated 
    true composite extent counter (S2 and EX combined), and saves the file cleanly.
    Correctly reassembles files spanning multiple directory entries (i.e. files
    longer than 16 blocks / 32KB, which need more than one directory entry).
    """
    target_filename = target_filename.upper().strip()
    file_extents = [e for e in entries if e["filename"] == target_filename]
    
    if not file_extents:
        print(f"\n[!] Error: File '{target_filename}' not found.")
        return

    # Sort extents by the mathematical composite True Extent.
    # The record listing index 'index' works as a fallback tie-breaker.
    file_extents.sort(key=lambda x: (x["true_extent"], x["index"]))
    
    print(f"\nExtracting '{target_filename}' ({len(file_extents)} entry segments found)...")
    
    output_data = bytearray()
    
    try:
        with open(image_path, "rb") as f:
            for idx, extent in enumerate(file_extents):
                is_last_extent = (idx == len(file_extents) - 1)
                active_blocks = [b for b in extent["blocks"] if b != 0]

                if not active_blocks:
                    continue

                entry_bytes_needed = calculate_extent_byte_size(
                    len(active_blocks), extent["records"], is_last_extent, extent["s1_size"]
                )

                entry_data = bytearray()
                for block in active_blocks:
                    entry_data.extend(read_block(f, block))

                output_data.extend(entry_data[:entry_bytes_needed])

                print(f"    extent #{idx} (true_extent={extent['true_extent']}): "
                      f"{len(active_blocks)} blocks -> {entry_bytes_needed} bytes"
                      f"{' [final]' if is_last_extent else ''}")

        # Check for trailing CP/M text EOF markers
        text_extensions = ["TXT", "ASM", "BAT", "SUB", "A86", "H", "C", "PAS", "DOC"]
        file_ext = target_filename.split(".")[-1] if "." in target_filename else ""
        
        if file_ext in text_extensions:
            eof_index = output_data.find(0x1A)
            if eof_index != -1:
                output_data = output_data[:eof_index]

        # Save out to current directory
        out_filename = target_filename.lower()
        with open(out_filename, "wb") as out_f:
            out_f.write(output_data)
            
        print(f"[+] Success! Extracted {len(output_data)} bytes to: '{out_filename}'")
        
    except Exception as e:
        print(f"[!] Extraction breakdown error: {e}")

def load_directory(image_path):
    dir_start_offset = logical_track_to_physical_offset(TRACK_OFFSET)
    dir_total_size = DIRECTORY_BLOCKS * BLOCK_SIZE
    with open(image_path, "rb") as f:
        f.seek(dir_start_offset)
        dir_data = f.read(dir_total_size)
    return parse_entries(dir_data)

def print_directory(image_path, entries):
    print("\n" + "=" * 90)
    print(f"DIRECTORY MAP FOR: {os.path.basename(image_path)}")
    print("=" * 90)
    print(f"{'Index':<6} {'User':<5} {'Filename':<18} {'EX':<4} {'S2':<4} {'TrueExt':<8} {'Records':<8} {'Active Blocks'}")
    print("-" * 90)

    for e in entries:
        attr_list = []
        if e["is_ro"]: attr_list.append("R/O")
        if e["is_sys"]: attr_list.append("SYS")
        attr_str = f" ({','.join(attr_list)})" if attr_list else ""

        active_blocks = [b for b in e["blocks"] if b != 0]
        print(f"{e['index']:<6} {e['user']:<5} {e['filename'] + attr_str:<18} "
              f"{e['ex']:<4} {e['s2']:<4} {e['true_extent']:<8} {e['records']:<8} {active_blocks}")

    print("-" * 90)
    print(f"Total matching directory entries parsed: {len(entries)}\n")

def main():
    print(f"--- CP/M-86 Disk Image Extractor / Injector (True EX + S2 Extent Assembly) ---")
    
    while True:
        image_path = input("Enter path to CP/M-86 disk image (or 'q' to quit): ").strip()
        if image_path.lower() == 'q': return
        if os.path.exists(image_path): break
        print(f"[!] File '{image_path}' not found.\n")

    try:
        entries = load_directory(image_path)
    except Exception as e:
        print(f"[!] Error accessing image data: {e}")
        return

    print_directory(image_path, entries)

    while True:
        print("[x] Extract a file   [i] Inject a file   [d] Delete a file   [l] List directory   [q] Quit")
        choice = input("> ").strip().lower()

        if choice == 'q' or choice == '':
            break

        elif choice == 'x':
            target = input("Enter exact filename to extract (e.g., COMMAND.CMD): ").strip()
            if target:
                extract_file(image_path, target, entries)

        elif choice == 'i':
            host_path = input("Path to the host file to inject: ").strip()
            cpm_name = input("CP/M filename to give it (blank = use host filename): ").strip()
            user_str = input("User number (0-15, blank = 0): ").strip()
            try:
                user_code = int(user_str) if user_str else 0
            except ValueError:
                print("[!] Invalid user number, defaulting to 0.")
                user_code = 0
            ro = input("Mark read-only? (y/N): ").strip().lower() == 'y'
            sysf = input("Mark as SYS file? (y/N): ").strip().lower() == 'y'

            ok = inject_file(image_path, host_path, entries,
                              target_filename=(cpm_name or None),
                              user_code=user_code, read_only=ro, system_file=sysf)
            if ok:
                entries = load_directory(image_path)
                print_directory(image_path, entries)

        elif choice == 'd':
            target = input("Enter exact filename to delete (e.g., OLDFILE.TXT): ").strip()
            if target:
                confirm = input(f"Really delete '{target.upper()}'? (y/N): ").strip().lower()
                if confirm == 'y':
                    ok = delete_file(image_path, target, entries)
                    if ok:
                        entries = load_directory(image_path)
                        print_directory(image_path, entries)

        elif choice == 'l':
            entries = load_directory(image_path)
            print_directory(image_path, entries)

        else:
            print("[!] Unrecognized option.\n")

if __name__ == "__main__":
    main()
