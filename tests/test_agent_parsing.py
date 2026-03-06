import unittest
import re

# Mocking the regex logic from ai_agent.py
def parse_remediation(action_text):
    results = []
    
    # RESTART
    restart_match = re.search(r"RESTART DEPLOYMENT [\'\`\"]?([\w-]+)[\'\`\"]? IN [\'\`\"]?([\w-]+)[\'\`\"]?", action_text, re.IGNORECASE)
    if restart_match:
        results.append(("RESTART", restart_match.group(1), restart_match.group(2)))
        
    # SCALE
    scale_match = re.search(r"SCALE DEPLOYMENT [\'\`\"]?([\w-]+)[\'\`\"]? IN [\'\`\"]?([\w-]+)[\'\`\"]? TO (\d+)", action_text, re.IGNORECASE)
    if scale_match:
        results.append(("SCALE", scale_match.group(1), scale_match.group(2), int(scale_match.group(3))))
        
    # ROLLBACK
    rollback_match = re.search(r"ROLLBACK DEPLOYMENT [\'\`\"]?([\w-]+)[\'\`\"]? IN [\'\`\"]?([\w-]+)[\'\`\"]?", action_text, re.IGNORECASE)
    if rollback_match:
        results.append(("ROLLBACK", rollback_match.group(1), rollback_match.group(2)))
        
    return results

class TestAgentParsing(unittest.TestCase):
    def test_restart_parsing(self):
        text = "I recommend: RESTART DEPLOYMENT 'frontend' IN 'online-boutique'"
        res = parse_remediation(text)
        self.assertEqual(res[0], ("RESTART", "frontend", "online-boutique"))
        
        text2 = "Action: RESTART DEPLOYMENT `cartservice` IN online-boutique"
        res2 = parse_remediation(text2)
        self.assertEqual(res2[0], ("RESTART", "cartservice", "online-boutique"))

    def test_scale_parsing(self):
        text = "SCALE DEPLOYMENT paymentservice IN online-boutique TO 5"
        res = parse_remediation(text)
        self.assertEqual(res[0], ("SCALE", "paymentservice", "online-boutique", 5))

    def test_rollback_parsing(self):
        text = "Remediation: ROLLBACK DEPLOYMENT \"shippingservice\" IN \"online-boutique\""
        res = parse_remediation(text)
        self.assertEqual(res[0], ("ROLLBACK", "shippingservice", "online-boutique"))

if __name__ == "__main__":
    unittest.main()
