
import os
import csv
import sys

def test_write_permissions():
    print("Starting Write Diagnostic...")
    
    # 1. Calculate Path exactly like the main script
    current_dir = os.path.dirname(os.path.abspath(__file__))
    target_dir = os.path.abspath(os.path.join(current_dir, "../data"))
    target_file = os.path.join(target_dir, "genetic_output.csv")
    
    print(f"Target Directory: {target_dir}")
    print(f"Target File:      {target_file}")
    
    # 2. Verify Directory Exists
    if not os.path.exists(target_dir):
        print("FAILURE: The 'data' directory does not exist.")
        try:
            os.makedirs(target_dir)
            print("   (I created it for you just now. Try running the main script again.)")
        except Exception as e:
            print(f"   (I tried to create it but failed: {e})")
        return

    # 3. Attempt Write
    try:
        with open(target_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["Diagnostic", "Test"])
            writer.writerow(["Result", "Success"])
            
            # Force write to disk
            f.flush()
            os.fsync(f.fileno())
            
        print("WRITE SUCCESS: Python says it wrote the file.")
    except PermissionError:
        print("PERMISSION ERROR: The file is likely open in Excel or another program.")
    except Exception as e:
        print(f"WRITE ERROR: {e}")

    # 4. Verify Read
    if os.path.exists(target_file):
        print("Verification: File found on disk.")
    else:
        print("GHOST ERROR: Python didn't crash, but the file is missing.")

if __name__ == "__main__":
    test_write_permissions()